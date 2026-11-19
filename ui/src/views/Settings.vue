<!--
  Copyright (C) 2022 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("settings.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-configuration')"
          :description="error.getConfiguration"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-form @submit.prevent="configureModule">
            <NsTextInput
              :label="$t('settings.termix_fqdn')"
              placeholder="termix.example.org"
              v-model.trim="host"
              class="mg-bottom"
              :invalid-message="error.host"
              :aria-invalid="Boolean(error.host)"
              :disabled="loading.getConfiguration || loading.configureModule"
              ref="host"
            >
            </NsTextInput>
            <cv-toggle
              value="letsEncrypt"
              :label="$t('settings.lets_encrypt')"
              v-model="isLetsEncryptEnabled"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="mg-bottom"
            >
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </cv-toggle>
            <cv-toggle
              value="httpToHttps"
              :label="$t('settings.http_to_https')"
              v-model="isHttpToHttpsEnabled"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="mg-bottom"
            >
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </cv-toggle>
            <h3 class="mg-bottom">{{ $t("settings.oidc_settings") }}</h3>
            <cv-select
              v-model="oidcMode"
              :label="$t('settings.oidc_mode')"
              :invalid-message="error.oidc_mode"
              :aria-invalid="Boolean(error.oidc_mode)"
              :helper-text="
                oidcMode === 'native' ? $t('settings.oidc_native_help') : ''
              "
              :disabled="busy"
              class="maxwidth mg-bottom"
              ref="oidc_mode"
            >
              <cv-select-option value="native">{{
                $t("settings.oidc_native")
              }}</cv-select-option>
              <cv-select-option value="ns8">{{
                $t("settings.oidc_ns8")
              }}</cv-select-option>
              <cv-select-option value="manual">{{
                $t("settings.oidc_manual")
              }}</cv-select-option>
            </cv-select>
            <template v-if="oidcMode !== 'native'">
              <NsInlineNotification
                kind="warning"
                :title="$t('settings.oidc_single_provider')"
                :description="$t('settings.oidc_plugin_help')"
                :showCloseButton="false"
                class="maxwidth mg-bottom"
              />
              <template v-if="oidcMode === 'ns8'">
                <cv-select
                  v-model="oidcProvider"
                  :label="$t('settings.oidc_provider')"
                  :helper-text="
                    oidcProviders.length ? '' : $t('settings.oidc_no_providers')
                  "
                  :invalid-message="error.oidc_provider"
                  :aria-invalid="Boolean(error.oidc_provider)"
                  :disabled="busy"
                  @change="oidcDomain = ''"
                  class="maxwidth mg-bottom"
                  ref="oidc_provider"
                >
                  <cv-select-option value="" disabled>{{
                    $t("settings.oidc_select_provider")
                  }}</cv-select-option>
                  <cv-select-option
                    v-if="oidcProvider && !selectedProvider"
                    :value="oidcProvider"
                    disabled
                    >{{
                      $t("settings.oidc_provider_unavailable")
                    }}</cv-select-option
                  >
                  <cv-select-option
                    v-for="provider in oidcProviders"
                    :key="provider.id"
                    :value="provider.id"
                    >{{ provider.label }}</cv-select-option
                  >
                </cv-select>
                <cv-select
                  v-if="oidcProvider"
                  v-model="oidcDomain"
                  :label="$t('settings.oidc_domain')"
                  :helper-text="
                    oidcDomains.length ? '' : $t('settings.oidc_no_domains')
                  "
                  :invalid-message="error.oidc_domain"
                  :aria-invalid="Boolean(error.oidc_domain)"
                  :disabled="busy"
                  class="maxwidth mg-bottom"
                  ref="oidc_domain"
                >
                  <cv-select-option value="" disabled>{{
                    $t("settings.oidc_select_domain")
                  }}</cv-select-option>
                  <cv-select-option
                    v-if="oidcDomain && !oidcDomains.includes(oidcDomain)"
                    :value="oidcDomain"
                    disabled
                    >{{
                      $t("settings.oidc_domain_unavailable")
                    }}</cv-select-option
                  >
                  <cv-select-option
                    v-for="domain in oidcDomains"
                    :key="domain"
                    :value="domain"
                    >{{ domain }}</cv-select-option
                  >
                </cv-select>
              </template>
              <template v-else>
                <NsTextInput
                  :label="$t('settings.oidc_issuer_url')"
                  placeholder="https://auth.example.org"
                  v-model.trim="oidcIssuerUrl"
                  :invalid-message="error.oidc_issuer_url"
                  :aria-invalid="Boolean(error.oidc_issuer_url)"
                  :disabled="busy"
                  class="maxwidth mg-bottom"
                  ref="oidc_issuer_url"
                />
                <NsTextInput
                  :label="$t('settings.oidc_client_id')"
                  v-model.trim="oidcClientId"
                  :invalid-message="error.oidc_client_id"
                  :aria-invalid="Boolean(error.oidc_client_id)"
                  :disabled="busy"
                  class="maxwidth mg-bottom"
                  ref="oidc_client_id"
                />
                <NsTextInput
                  :label="$t('settings.oidc_client_secret')"
                  type="password"
                  autocomplete="new-password"
                  v-model="oidcClientSecret"
                  :helper-text="
                    keepsSecret ? $t('settings.oidc_keep_secret') : ''
                  "
                  :password-show-label="$t('settings.oidc_show_secret')"
                  :password-hide-label="$t('settings.oidc_hide_secret')"
                  :invalid-message="error.oidc_client_secret"
                  :aria-invalid="Boolean(error.oidc_client_secret)"
                  :disabled="busy"
                  class="maxwidth mg-bottom"
                  ref="oidc_client_secret"
                />
                <cv-accordion
                  class="maxwidth mg-bottom"
                  @cv:change="advancedOpen = $event.dataOpen"
                >
                  <cv-accordion-item :open="advancedOpen">
                    <template slot="title">{{
                      $t("settings.advanced")
                    }}</template>
                    <template slot="content">
                      <p class="mg-bottom">
                        {{ $t("settings.oidc_discovery_help") }}
                      </p>
                      <NsTextInput
                        :label="$t('settings.oidc_authorization_url')"
                        placeholder="https://auth.example.org/authorize"
                        v-model.trim="oidcAuthorizationUrl"
                        :invalid-message="error.oidc_authorization_url"
                        :aria-invalid="Boolean(error.oidc_authorization_url)"
                        :disabled="busy"
                        class="mg-bottom"
                        ref="oidc_authorization_url"
                      />
                      <NsTextInput
                        :label="$t('settings.oidc_token_url')"
                        placeholder="https://auth.example.org/token"
                        v-model.trim="oidcTokenUrl"
                        :invalid-message="error.oidc_token_url"
                        :aria-invalid="Boolean(error.oidc_token_url)"
                        :disabled="busy"
                        class="mg-bottom"
                        ref="oidc_token_url"
                      />
                      <NsTextInput
                        :label="$t('settings.oidc_userinfo_url')"
                        placeholder="https://auth.example.org/userinfo"
                        v-model.trim="oidcUserinfoUrl"
                        :invalid-message="error.oidc_userinfo_url"
                        :aria-invalid="Boolean(error.oidc_userinfo_url)"
                        :disabled="busy"
                        class="mg-bottom"
                        ref="oidc_userinfo_url"
                      />
                      <NsTextInput
                        :label="$t('settings.oidc_identifier_path')"
                        placeholder="sub"
                        v-model.trim="oidcIdentifierPath"
                        :invalid-message="error.oidc_identifier_path"
                        :aria-invalid="Boolean(error.oidc_identifier_path)"
                        :disabled="busy"
                        class="mg-bottom"
                        ref="oidc_identifier_path"
                      />
                      <NsTextInput
                        :label="$t('settings.oidc_name_path')"
                        placeholder="name"
                        v-model.trim="oidcNamePath"
                        :invalid-message="error.oidc_name_path"
                        :aria-invalid="Boolean(error.oidc_name_path)"
                        :disabled="busy"
                        class="mg-bottom"
                        ref="oidc_name_path"
                      />
                      <NsTextInput
                        :label="$t('settings.oidc_scopes')"
                        placeholder="openid email profile"
                        v-model.trim="oidcScopes"
                        :invalid-message="error.oidc_scopes"
                        :aria-invalid="Boolean(error.oidc_scopes)"
                        :disabled="busy"
                        class="mg-bottom"
                        ref="oidc_scopes"
                      />
                    </template>
                  </cv-accordion-item>
                </cv-accordion>
              </template>
              <NsTextInput
                v-if="oidcCallbackUrl"
                :label="$t('settings.oidc_callback')"
                :value="oidcCallbackUrl"
                readonly
                class="maxwidth mg-bottom"
              />
              <NsToggle
                value="allowPasswordLogin"
                :label="$t('settings.oidc_allow_password_login')"
                v-model="oidcAllowPasswordLogin"
                :disabled="busy"
                class="mg-bottom"
              >
                <template slot="text-left">{{
                  $t("settings.disabled")
                }}</template>
                <template slot="text-right">{{
                  $t("settings.enabled")
                }}</template>
              </NsToggle>
              <NsToggle
                value="silentLogin"
                :label="$t('settings.oidc_silent_login')"
                v-model="oidcSilentLogin"
                :disabled="busy"
                class="mg-bottom"
              >
                <template slot="text-left">{{
                  $t("settings.disabled")
                }}</template>
                <template slot="text-right">{{
                  $t("settings.enabled")
                }}</template>
              </NsToggle>
              <NsInlineNotification
                v-if="!oidcAllowPasswordLogin || oidcSilentLogin"
                kind="warning"
                :title="$t('settings.oidc_outage_warning')"
                :showCloseButton="false"
                class="maxwidth mg-bottom"
              />
              <p class="mg-bottom">{{ $t("settings.oidc_recovery_help") }}</p>
              <NsCodeSnippet
                hideExpandButton
                :copyTooltip="$t('settings.oidc_copy_command')"
                class="maxwidth mg-bottom"
                >{{ recoveryCommand }}</NsCodeSnippet
              >
            </template>
            <cv-row v-if="error.configureModule">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="$t('action.configure-module')"
                  :description="error.configureModule"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <NsButton
              kind="primary"
              :icon="Save20"
              :loading="loading.configureModule"
              :disabled="loading.getConfiguration || loading.configureModule"
              >{{ $t("settings.save") }}</NsButton
            >
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";

export default {
  name: "Settings",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "settings",
      },
      urlCheckInterval: null,
      host: "",
      isLetsEncryptEnabled: false,
      isHttpToHttpsEnabled: true,
      oidcMode: "native",
      oidcProvider: "",
      oidcDomain: "",
      oidcProviders: [],
      oidcAllowPasswordLogin: true,
      oidcSilentLogin: false,
      oidcCallbackPath: "/plugin-api/sso/callback",
      savedOidc: {},
      advancedOpen: false,
      oidcClientId: "",
      oidcClientSecret: "",
      oidcIssuerUrl: "",
      oidcAuthorizationUrl: "",
      oidcTokenUrl: "",
      oidcUserinfoUrl: "",
      oidcIdentifierPath: "sub",
      oidcNamePath: "name",
      oidcScopes: "openid email profile",
      loading: {
        getConfiguration: false,
        configureModule: false,
      },
      error: {
        getConfiguration: "",
        configureModule: "",
        host: "",
        lets_encrypt: "",
        http2https: "",
        oidc_mode: "",
        oidc_provider: "",
        oidc_domain: "",
        oidc_client_id: "",
        oidc_client_secret: "",
        oidc_issuer_url: "",
        oidc_authorization_url: "",
        oidc_token_url: "",
        oidc_userinfo_url: "",
        oidc_identifier_path: "",
        oidc_name_path: "",
        oidc_scopes: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    busy() {
      return this.loading.getConfiguration || this.loading.configureModule;
    },
    selectedProvider() {
      return this.oidcProviders.find(({ id }) => id === this.oidcProvider);
    },
    oidcDomains() {
      return this.selectedProvider ? this.selectedProvider.domains : [];
    },
    sameManualClient() {
      return (
        this.savedOidc.oidc_mode === "manual" &&
        this.oidcIssuerUrl === this.savedOidc.oidc_issuer_url &&
        this.oidcClientId === this.savedOidc.oidc_client_id
      );
    },
    keepsSecret() {
      return this.savedOidc.oidc_secret_set && this.sameManualClient;
    },
    oidcCallbackUrl() {
      if (!this.host) return "";
      const path =
        this.oidcMode === "manual" &&
        this.sameManualClient &&
        this.savedOidc.oidc_legacy_callback
          ? "/users/oidc/callback"
          : this.oidcCallbackPath;
      return `https://${this.host}${path}`;
    },
    recoveryCommand() {
      return `runagent -m ${this.instanceName} termix-restore-password-login`;
    },
  },
  created() {
    this.getConfiguration();
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  methods: {
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getConfigurationAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getConfigurationCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
        return;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      const config = taskResult.output;
      this.host = config.host;
      this.isLetsEncryptEnabled = config.lets_encrypt;
      this.isHttpToHttpsEnabled = config.http2https;

      this.savedOidc = config;
      this.oidcMode = config.oidc_mode || "native";
      this.oidcProvider = config.oidc_provider || "";
      this.oidcDomain = config.oidc_domain || "";
      this.oidcProviders = config.oidc_providers || [];
      this.oidcAllowPasswordLogin = config.oidc_allow_password_login !== false;
      this.oidcSilentLogin = config.oidc_silent_login === true;
      this.oidcCallbackPath =
        config.oidc_callback_path || "/plugin-api/sso/callback";

      const manual = this.oidcMode === "manual" ? config : {};
      this.oidcClientId = manual.oidc_client_id || "";
      this.oidcClientSecret = "";
      this.oidcIssuerUrl = manual.oidc_issuer_url || "";
      this.oidcAuthorizationUrl = manual.oidc_authorization_url || "";
      this.oidcTokenUrl = manual.oidc_token_url || "";
      this.oidcUserinfoUrl = manual.oidc_userinfo_url || "";
      this.oidcIdentifierPath = manual.oidc_identifier_path || "sub";
      this.oidcNamePath = manual.oidc_name_path || "name";
      this.oidcScopes = manual.oidc_scopes || "openid email profile";

      this.loading.getConfiguration = false;
      this.focusElement("host");
    },
    validateConfigureModule() {
      this.clearErrors(this);

      const required = { host: this.host };
      if (this.oidcMode === "ns8") {
        required.oidc_provider = this.oidcProvider;
        required.oidc_domain = this.oidcDomain;
      } else if (this.oidcMode === "manual") {
        required.oidc_issuer_url = this.oidcIssuerUrl;
        required.oidc_client_id = this.oidcClientId;
        required.oidc_client_secret = this.oidcClientSecret || this.keepsSecret;
      }
      const emptyOptions = {
        oidc_provider:
          !this.oidcProviders.length && "settings.oidc_no_providers",
        oidc_domain: !this.oidcDomains.length && "settings.oidc_no_domains",
      };
      const missing = Object.keys(required).filter((field) => !required[field]);
      for (const field of missing) {
        this.error[field] = this.$t(emptyOptions[field] || "common.required");
      }
      if (missing.length) this.focusSettingsField(missing[0]);
      return !missing.length;
    },
    focusSettingsField(field) {
      if (
        [
          "oidc_authorization_url",
          "oidc_token_url",
          "oidc_userinfo_url",
          "oidc_identifier_path",
          "oidc_name_path",
          "oidc_scopes",
        ].includes(field)
      ) {
        this.advancedOpen = true;
      }
      this.$nextTick(() => {
        const component = this.$refs[field];
        const element = component && (component.$el || component);
        const control = element && element.querySelector("input, select");
        if (control) control.focus();
      });
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let firstVisibleField;
      for (const { parameter, error } of validationErrors) {
        const message = this.$t("settings." + error);
        if (parameter in this.error && this.$refs[parameter]) {
          this.error[parameter] = message;
          if (!firstVisibleField) firstVisibleField = parameter;
        } else {
          this.error.configureModule = message;
        }
      }
      if (firstVisibleField) this.focusSettingsField(firstVisibleField);
    },
    oidcPayload() {
      const data = { oidc_mode: this.oidcMode };
      if (this.oidcMode === "native") return data;
      data.oidc_allow_password_login = this.oidcAllowPasswordLogin;
      data.oidc_silent_login = this.oidcSilentLogin;
      if (this.oidcMode === "ns8") {
        data.oidc_provider = this.oidcProvider;
        data.oidc_domain = this.oidcDomain;
      } else {
        Object.assign(data, {
          oidc_client_id: this.oidcClientId,
          oidc_client_secret: this.oidcClientSecret,
          oidc_issuer_url: this.oidcIssuerUrl,
          oidc_authorization_url: this.oidcAuthorizationUrl,
          oidc_token_url: this.oidcTokenUrl,
          oidc_userinfo_url: this.oidcUserinfoUrl,
          oidc_identifier_path: this.oidcIdentifierPath,
          oidc_name_path: this.oidcNamePath,
          oidc_scopes: this.oidcScopes,
        });
      }
      return data;
    },
    async configureModule() {
      const isValidationOk = this.validateConfigureModule();
      if (!isValidationOk) {
        return;
      }

      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            host: this.host,
            lets_encrypt: this.isLetsEncryptEnabled,
            http2https: this.isHttpToHttpsEnabled,
            ...this.oidcPayload(),
          },
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },
    configureModuleAborted(_taskResult, taskContext) {
      // Configuration task results can contain write-only request fields.
      console.error(`${taskContext.action} aborted`);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;

      // reload configuration
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: $spacing-06;
}

.maxwidth {
  max-width: 38rem;
}
</style>
