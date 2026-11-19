# SPDX-License-Identifier: GPL-3.0-or-later

import fcntl
import json
import os
from contextlib import contextmanager
from pathlib import Path
import re
import sys
import tempfile
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

CALLBACK = "/plugin-api/sso/callback"
LEGACY_CALLBACK = "/users/oidc/callback"
ENV = Path(os.environ.get("AGENT_STATE_DIR", ".")) / "termix.env"
FIELDS = {
    "oidc_client_id": ("OIDC_CLIENT_ID", ""),
    "oidc_client_secret": ("OIDC_CLIENT_SECRET", ""),
    "oidc_issuer_url": ("OIDC_ISSUER_URL", ""),
    "oidc_authorization_url": ("OIDC_AUTHORIZATION_URL", ""),
    "oidc_token_url": ("OIDC_TOKEN_URL", ""),
    "oidc_userinfo_url": ("OIDC_USERINFO_URL", ""),
    "oidc_identifier_path": ("OIDC_IDENTIFIER_PATH", "sub"),
    "oidc_name_path": ("OIDC_NAME_PATH", "name"),
    "oidc_scopes": ("OIDC_SCOPES", "openid email profile"),
}
MODE = "NS8_TERMIX_OIDC_MODE"
PROVIDER = "NS8_TERMIX_OIDC_PROVIDER"
DOMAIN = "NS8_TERMIX_OIDC_DOMAIN"
OWNED_BINDING = "NS8_TERMIX_OIDC_OWNED_BINDING"
REGISTERED_CALLBACK = "NS8_TERMIX_OIDC_CALLBACK"
NAMESPACE_ISSUER = "NS8_TERMIX_OIDC_IDENTITY_ISSUER"
NAMESPACE_CLAIM = "NS8_TERMIX_OIDC_IDENTITY_CLAIM"
PASSWORD_LOGIN = "ALLOW_PASSWORD_LOGIN"
SILENT_LOGIN = "OIDC_SILENT_LOGIN_DEFAULT"
ISSUER = "OIDC_ISSUER_URL"
IDENTIFIER = "OIDC_IDENTIFIER_PATH"
REQUIRED_ENV = ("OIDC_CLIENT_ID", "OIDC_CLIENT_SECRET", ISSUER,
                "OIDC_AUTHORIZATION_URL", "OIDC_TOKEN_URL")


class ConfigError(Exception):
    def __init__(self, field, code):
        super().__init__(code)
        self.field = field


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def enabled(value):
    return value.lower() == "true"


def mode(values):
    return values.get(MODE) or ("manual" if any(values.get(key) for key in REQUIRED_ENV) else "native")


def read():
    import agent

    try:
        return agent.read_envfile(ENV)
    except FileNotFoundError:
        return {}


@contextmanager
def locked():
    with ENV.with_suffix(".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def write(values):
    with tempfile.NamedTemporaryFile(mode="w", dir=ENV.parent, delete=False) as stream:
        try:
            for key, value in sorted(values.items()):
                stream.write(f"{key}={value}\n")
            stream.flush()
            os.replace(stream.name, ENV)
        finally:
            Path(stream.name).unlink(missing_ok=True)


def https_url(value, issuer=False):
    try:
        url = urlsplit(value)
        return (
            url.scheme == "https" and bool(url.hostname) and url.port != 0
            and url.username is None and url.password is None and "#" not in value
            and (not issuer or "?" not in value)
            and not any(char.isspace() or ord(char) < 32 or char == "\\" for char in value)
        )
    except ValueError:
        return False


def providers(rdb):
    import agent
    from agent.ldapproxy import Ldapproxy

    domains = sorted(Ldapproxy().get_domains_list())
    result = {}
    for record in agent.list_service_providers(rdb, "oidc", "http", sortby="module_seq_asc"):
        module = record.get("module_id", "")
        uuid = record.get("module_uuid")
        host = record.get("host", "")
        prefix = record.get("issuer_url_prefix", "")
        if not uuid or not re.fullmatch(r"(?:idp|keycloak|lemonldapng)[0-9]+", module):
            continue
        if not https_url(prefix, issuer=True) or not prefix.startswith(f"https://{host}/") or not prefix.endswith("/"):
            continue
        domain = record.get("domain", "")
        result[uuid] = {
            "id": uuid, "module": module, "label": record.get("ui_name") or module,
            "prefix": prefix, "domains": [name for name in domains if not domain or domain == name],
        }
    return result


def discovery(issuer, field):
    try:
        url = issuer.rstrip("/") + "/.well-known/openid-configuration"
        request = Request(url, headers={"Accept": "application/json"})
        with build_opener(NoRedirect()).open(request, timeout=10) as response:
            document = json.loads(response.read(256 * 1024))
        if document["issuer"].rstrip("/") != issuer.rstrip("/"):
            raise ValueError()
        endpoints = {
            "OIDC_AUTHORIZATION_URL": document["authorization_endpoint"],
            "OIDC_TOKEN_URL": document["token_endpoint"],
        }
        if document.get("userinfo_endpoint"):
            endpoints["OIDC_USERINFO_URL"] = document["userinfo_endpoint"]
        if not all(isinstance(url, str) and https_url(url) for url in endpoints.values()):
            raise ValueError()
        return endpoints
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        raise ConfigError(field, "oidc_discovery_failed") from None


def validate_namespace(current, issuer, claim, field):
    pinned_issuer = current.get(NAMESPACE_ISSUER)
    pinned_claim = current.get(NAMESPACE_CLAIM, "sub")
    if not pinned_issuer and all(current.get(key) for key in REQUIRED_ENV):
        pinned_issuer, pinned_claim = current[ISSUER], current.get(IDENTIFIER) or "sub"
    if pinned_issuer and (pinned_issuer.rstrip("/"), pinned_claim) != (issuer.rstrip("/"), claim):
        raise ConfigError(field, "oidc_identity_namespace_changed")


def manual(request, current):
    existing_manual = mode(current) == "manual"
    values = {}
    for field, (key, default) in FIELDS.items():
        value = request.get(field, current.get(key, default) if existing_manual else default)
        if any(char in value for char in "\r\n\0"):
            raise ConfigError(field, "oidc_invalid_value")
        values[key] = value
    issuer = values[ISSUER]
    if not https_url(issuer, issuer=True):
        raise ConfigError("oidc_issuer_url", "oidc_invalid_url")
    if not values["OIDC_CLIENT_ID"].strip():
        raise ConfigError("oidc_client_id", "oidc_required")
    same_client = (issuer, values["OIDC_CLIENT_ID"]) == (current.get(ISSUER), current.get("OIDC_CLIENT_ID"))
    secret = request.get("oidc_client_secret", "")
    if not secret and same_client and existing_manual:
        secret = current.get("OIDC_CLIENT_SECRET", "")
    if not secret:
        raise ConfigError("oidc_client_secret", "oidc_required")
    values["OIDC_CLIENT_SECRET"] = secret
    values[IDENTIFIER] = values[IDENTIFIER] or "sub"
    validate_namespace(current, issuer, values[IDENTIFIER], "oidc_issuer_url")

    for field in ("oidc_authorization_url", "oidc_token_url", "oidc_userinfo_url"):
        value = values[FIELDS[field][0]]
        if value and not https_url(value):
            raise ConfigError(field, "oidc_invalid_url")
    if not values["OIDC_AUTHORIZATION_URL"] or not values["OIDC_TOKEN_URL"]:
        for key, endpoint in discovery(issuer, "oidc_issuer_url").items():
            if not values[key]:
                values[key] = endpoint
    if same_client and existing_manual:
        values["OIDC_LEGACY_CALLBACK"] = current.get("OIDC_LEGACY_CALLBACK", "true")
    else:
        values["OIDC_LEGACY_CALLBACK"] = "false"
    return values


def managed(request, current, refresh=False):
    import agent
    import agent.tasks

    provider = request.get("oidc_provider", current.get(PROVIDER, ""))
    domain = request.get("oidc_domain", current.get(DOMAIN, ""))
    callback = f"https://{request['host']}{CALLBACK}"
    rdb = agent.redis_connect()
    bound = agent.get_bound_domain_list(rdb)
    module = os.environ["MODULE_ID"]
    if (
        not refresh and mode(current) == "ns8" and provider == current.get(PROVIDER)
        and domain == current.get(DOMAIN) and current.get(REGISTERED_CALLBACK) == callback
        and current.get("OIDC_CLIENT_ID") == module and domain in bound
    ):
        return {key: current[key] for key in [
            *(var for var, _ in FIELDS.values()), PROVIDER, DOMAIN, OWNED_BINDING,
            REGISTERED_CALLBACK, "OIDC_LEGACY_CALLBACK",
        ] if key in current}

    endpoint = providers(rdb).get(provider)
    if not endpoint:
        raise ConfigError("oidc_provider", "oidc_provider_unavailable")
    if domain not in endpoint["domains"]:
        raise ConfigError("oidc_domain", "oidc_domain_unavailable")
    issuer = endpoint["prefix"] + domain
    validate_namespace(current, issuer, "sub", "oidc_provider")

    added = domain not in bound
    if added and not agent.bind_user_domains([*bound, domain]):
        raise ConfigError("oidc_domain", "oidc_registration_failed")
    try:
        try:
            result = agent.tasks.run(
                f"module/{endpoint['module']}", "register-client",
                data={"domain": domain, "redirect_uris": [callback], "post_logout_redirect_uris": []},
                extra={"isNotificationHidden": True},
            )
            response = result.get("output")
            if result.get("exit_code") != 0 or not isinstance(response, dict):
                raise ValueError()
            secret = response.get("client_secret")
            if (
                response.get("issuer") != issuer or response.get("realm") != domain
                or response.get("client_id") != module or not isinstance(secret, str)
                or not secret or any(char in secret for char in "\r\n\0")
            ):
                raise ValueError()
        except Exception:
            raise ConfigError("oidc_provider", "oidc_registration_failed") from None
        endpoints = discovery(issuer, "oidc_provider")
    except ConfigError:
        if added:
            agent.bind_user_domains(bound)
        raise

    return {
        "OIDC_CLIENT_ID": module, "OIDC_CLIENT_SECRET": secret, ISSUER: issuer,
        **endpoints, IDENTIFIER: "sub", "OIDC_NAME_PATH": "preferred_username",
        "OIDC_SCOPES": "openid email profile", "OIDC_LEGACY_CALLBACK": "false",
        PROVIDER: provider, DOMAIN: domain, REGISTERED_CALLBACK: callback,
        OWNED_BINDING: str(added or (
            enabled(current.get(OWNED_BINDING, "")) and current.get(DOMAIN) == domain
        )).lower(),
    }


def configure(request, current, refresh=False):
    port = request.get("PORT", current.get("PORT", "8080"))
    selected = request.get("oidc_mode")
    legacy_fields = ("oidc_client_id", "oidc_client_secret", "oidc_issuer_url",
                     "oidc_authorization_url", "oidc_token_url")
    legacy_edit = any(request.get(field) for field in legacy_fields)
    if selected is None and not legacy_edit and "oidc_client_id" in request and "oidc_issuer_url" in request:
        selected = "native"
    if selected is None and not legacy_edit and mode(current) != "ns8":
        # Host-only saves, restores and older callers must preserve legacy
        # settings, including native UI precedence and the original callback.
        return {**current, "PORT": port}

    managed_keys = {
        *(key for key, _ in FIELDS.values()), MODE, PROVIDER, DOMAIN, OWNED_BINDING,
        REGISTERED_CALLBACK, NAMESPACE_ISSUER, NAMESPACE_CLAIM, "OIDC_ENV_OVERRIDE",
        "OIDC_LEGACY_CALLBACK", "EXTERNAL_FORCE_HTTPS", PASSWORD_LOGIN, SILENT_LOGIN,
    }
    values = {key: value for key, value in current.items() if key not in managed_keys}
    values["PORT"] = port
    old_issuer = current.get(NAMESPACE_ISSUER)
    if not old_issuer and all(current.get(key) for key in REQUIRED_ENV):
        values[NAMESPACE_ISSUER] = current[ISSUER]
        values[NAMESPACE_CLAIM] = current.get(IDENTIFIER) or "sub"
    elif old_issuer:
        values[NAMESPACE_ISSUER] = old_issuer
        values[NAMESPACE_CLAIM] = current[NAMESPACE_CLAIM]

    if selected == "native":
        values[MODE] = "native"
        return values

    selected = selected or ("manual" if legacy_edit else "ns8")
    values.update(managed(request, current, refresh=refresh) if selected == "ns8" else manual(request, current))
    values.update({
        MODE: selected,
        NAMESPACE_ISSUER: values[ISSUER],
        NAMESPACE_CLAIM: values[IDENTIFIER],
        "OIDC_ENV_OVERRIDE": "true",
        "EXTERNAL_FORCE_HTTPS": "true",
        PASSWORD_LOGIN: str(request.get("oidc_allow_password_login", enabled(current.get(PASSWORD_LOGIN, "true")))).lower(),
        SILENT_LOGIN: str(request.get("oidc_silent_login", enabled(current.get(SILENT_LOGIN, "false")))).lower(),
    })
    return values


def save(values, previous):
    import agent

    old_domain = previous.get(DOMAIN)
    if old_domain and old_domain != values.get(DOMAIN) and enabled(previous.get(OWNED_BINDING, "")):
        bound = agent.get_bound_domain_list(agent.redis_connect())
        if old_domain in bound:
            agent.bind_user_domains([domain for domain in bound if domain != old_domain], check=True)
    write(values)


def report(error):
    import agent

    agent.set_status("validation-failed")
    json.dump([{"field": error.field, "parameter": error.field, "value": "", "error": str(error)}], sys.stdout)
    raise SystemExit(3)
