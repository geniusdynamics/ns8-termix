*** Settings ***
Library    SSHLibrary
Library    Collections

*** Variables ***
${SCENARIO}         install
# Termix is not in the default software repositories, so the update scenario
# installs the previous release by image URL instead of by name
${PREVIOUS_IMAGE}   ghcr.io/geniusdynamics/termix:latest
${HOST}             termix.test.local
${ADMIN_USER}       admin
${ADMIN_PASSWORD}   Nethesis,1234
${module_id}        ${EMPTY}
${managed_id}       ${EMPTY}
${directory_id}     ${EMPTY}
${keycloak_id}      ${EMPTY}
${OIDC_DOMAIN}      termix-ci.example.org
${KEYCLOAK_HOST}    keycloak.${OIDC_DOMAIN}
${MANAGED_HOST}     termix.${OIDC_DOMAIN}
${CA_DIR}           /root/termix-oidc-ci

*** Keywords ***
Login to cluster-admin
    New Page    https://${NODE_ADDR}/cluster-admin/
    Fill Text    text="Username"    ${ADMIN_USER}
    Click    button >> text="Continue"
    Fill Text    text="Password"    ${ADMIN_PASSWORD}
    Click    button >> text="Log in"
    Wait For Elements State    css=#main-content    visible    timeout=10s

Termix answers through Traefik
    ${rc} =    Execute Command    curl -f -H 'Host: ${HOST}' http://127.0.0.1/
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Get configuration
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/get-configuration --data null
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{config} =    Evaluate    json.loads('''${output}''')    modules=json
    RETURN    &{config}

Run node command
    [Arguments]    ${command}
    ${out}    ${err}    ${rc} =    Execute Command    ${command}    return_rc=True    return_stderr=True
    Should Be Equal As Integers    ${rc}    0    ${out} ${err}
    RETURN    ${out}

Install OIDC fixture
    [Arguments]    ${image}
    ${out} =    Run node command    add-module ${image} 1
    ${id} =    Evaluate    ast.literal_eval($out)['module_id']    ast
    RETURN    ${id}

Remove managed OIDC fixtures
    FOR    ${id}    IN    ${managed_id}    ${keycloak_id}    ${directory_id}
        IF    $id
            Run node command    remove-module --no-preserve ${id}
        END
    END

*** Test Cases ***
Check if termix is installed correctly
    IF    '${SCENARIO}' == 'update'
        ${output}  ${rc} =    Execute Command    add-module ${PREVIOUS_IMAGE} 1
        ...    return_rc=True
    ELSE
        ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
        ...    return_rc=True
    END
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${module_id}    ${output.module_id}

Check if termix can be configured
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '{"host": "${HOST}", "http2https": false, "lets_encrypt": false}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    Wait Until Keyword Succeeds    30 times    10 seconds    Termix answers through Traefik

Check if termix survives the update
    Skip If    '${SCENARIO}' != 'update'    scenario is ${SCENARIO}, nothing to update
    ${rc} =    Execute Command
    ...    api-cli run update-module --data '{"force":true,"module_url":"${IMAGE_URL}","instances":["${module_id}"]}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    &{config} =    Get configuration
    Should Be Equal    ${config.host}    ${HOST}
    Should Not Be True    ${config.http2https}
    Should Not Be True    ${config.lets_encrypt}

Check if termix works as expected
    Wait Until Keyword Succeeds    60 times    10 seconds    Termix answers through Traefik
    # Set by bin/prepare-termix-data once the data is ready for Termix 26.x
    ${rc} =    Execute Command
    ...    runagent -m ${module_id} sh -c 'podman unshare test -e "$(podman volume inspect -f "{{.Mountpoint}}" termix-data)/.ns8-termix-ready-v26"'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if OIDC settings can be saved
    # Blank OIDC URLs come from the Settings page as empty strings
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '{"host": "${HOST}", "http2https": false, "lets_encrypt": false, "oidc_client_id": "ci-client", "oidc_client_secret": "ci-not-a-secret", "oidc_issuer_url": "https://issuer.test.local", "oidc_authorization_url": "https://issuer.test.local/auth", "oidc_token_url": "https://issuer.test.local/token", "oidc_userinfo_url": ""}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    &{config} =    Get configuration
    Should Be Equal    ${config.oidc_client_id}    ci-client
    Should Be Equal    ${config.oidc_issuer_url}    https://issuer.test.local
    Should Be Equal    ${config.oidc_userinfo_url}    ${EMPTY}
    Wait Until Keyword Succeeds    30 times    10 seconds    Termix answers through Traefik

Check if module SSO settings control password login and silent redirect
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"host":"${HOST}","http2https":false,"lets_encrypt":false,"oidc_mode":"manual","oidc_client_id":"ci-client","oidc_issuer_url":"https://issuer.test.local","oidc_authorization_url":"https://issuer.test.local/auth","oidc_token_url":"https://issuer.test.local/token","oidc_allow_password_login":false,"oidc_silent_login":true}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}    0
    &{config} =    Get configuration
    Should Be True    ${config.oidc_secret_set}
    Should Not Be True    ${config.oidc_allow_password_login}
    Should Be True    ${config.oidc_silent_login}
    Dictionary Should Not Contain Key    ${config}    oidc_client_secret
    ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec termix-app sh -c 'test "$OIDC_ENV_OVERRIDE" = true && test "$ALLOW_PASSWORD_LOGIN" = false && test "$OIDC_SILENT_LOGIN_DEFAULT" = true && test -n "$OIDC_CLIENT_SECRET"'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}    0

Check if node recovery restores local login access
    ${rc} =    Execute Command    runagent -m ${module_id} termix-restore-password-login
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    30 times    10 seconds    Termix answers through Traefik
    ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec termix-app sh -c 'test "$ALLOW_PASSWORD_LOGIN" = true && test "$OIDC_SILENT_LOGIN_DEFAULT" = false'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}    0
    ${output}    ${rc} =    Execute Command    curl -fsS -H 'Host: ${HOST}' http://127.0.0.1/users/auth/methods    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    "password"

Check if returning to app-managed SSO unsets overrides
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"host":"${HOST}","http2https":false,"lets_encrypt":false,"oidc_mode":"native"}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}    0
    &{config} =    Get configuration
    Should Be Equal    ${config.oidc_mode}    native
    Should Not Be True    ${config.oidc_secret_set}
    ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec termix-app sh -c 'test -z "$OIDC_ENV_OVERRIDE" && test -z "$OIDC_CLIENT_ID" && test -z "$ALLOW_PASSWORD_LOGIN" && test -z "$OIDC_SILENT_LOGIN_DEFAULT"'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}    0

Check if a published NS8 provider registers a working Termix sign-in
    [Teardown]    Remove managed OIDC fixtures
    Skip If    '${SCENARIO}' == 'update'
    ${directory} =    Install OIDC fixture    ghcr.io/nethserver/openldap:2.8.1
    Set Suite Variable    ${directory_id}    ${directory}
    Run node command    api-cli run module/${directory_id}/configure-module --data '{"provision":"new-domain","domain":"${OIDC_DOMAIN}","admuser":"admin","admpass":"Termix-OIDC-CI-2026"}'
    ${keycloak} =    Install OIDC fixture    ghcr.io/geniusdynamics/keycloak:1.1.0
    Set Suite Variable    ${keycloak_id}    ${keycloak}
    Run node command    api-cli run module/${keycloak_id}/configure-module --data '{"host":"${KEYCLOAK_HOST}","http2https":true,"lets_encrypt":false}'
    Wait Until Keyword Succeeds    150s    5s    Run node command
    ...    curl -kfSs --resolve ${KEYCLOAK_HOST}:443:127.0.0.1 https://${KEYCLOAK_HOST}/realms/master/.well-known/openid-configuration >/dev/null
    Run node command    api-cli run module/${keycloak_id}/configure-ns8-sso --data '{"enabled":true}'
    Run node command    install -d -m 0700 ${CA_DIR}
    Run node command    cd ${CA_DIR} && openssl req -x509 -newkey rsa:2048 -nodes -subj /CN=Termix-OIDC-CI -keyout ca.key -out ca.crt -days 2 >/dev/null 2>&1
    Run node command
    ...    cd ${CA_DIR} && openssl req -new -newkey rsa:2048 -nodes -subj /CN=${KEYCLOAK_HOST} -keyout tls.key -out tls.csr >/dev/null 2>&1 && echo 'subjectAltName=DNS:${KEYCLOAK_HOST},DNS:${MANAGED_HOST}' > tls.ext && openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out tls.crt -days 2 -extfile tls.ext
    Run node command
    ...    if command -v update-ca-trust >/dev/null; then install -m 644 ${CA_DIR}/ca.crt /etc/pki/ca-trust/source/anchors/termix-oidc-ci.crt && update-ca-trust extract; else install -m 644 ${CA_DIR}/ca.crt /usr/local/share/ca-certificates/termix-oidc-ci.crt && update-ca-certificates >/dev/null; fi
    Run node command    echo '127.0.0.1 ${KEYCLOAK_HOST}' >> /etc/hosts
    Run node command
    ...    cd ${CA_DIR} && jq -n --rawfile cert tls.crt --rawfile key tls.key '{certFile:($cert|@base64),keyFile:($key|@base64)}' | api-cli run module/traefik1/upload-certificate --data -
    Wait Until Keyword Succeeds    45s    3s    Run node command
    ...    curl --noproxy '*' -fSs https://${KEYCLOAK_HOST}/realms/master/.well-known/openid-configuration >/dev/null
    ${termix} =    Install OIDC fixture    ${IMAGE_URL}
    Set Suite Variable    ${managed_id}    ${termix}
    Run node command
    ...    runagent -m ${managed_id} python3 -c 'from termix_sso import discovery; discovery("https://${KEYCLOAK_HOST}/realms/master", "oidc_provider")'
    ${uuid} =    Run node command    redis-cli --no-auth-warning HGET cluster/module_uuid ${keycloak_id}
    Run node command
    ...    api-cli run module/${managed_id}/configure-module --data '{"host":"${MANAGED_HOST}","http2https":true,"lets_encrypt":false,"oidc_mode":"ns8","oidc_provider":"${uuid}","oidc_domain":"${OIDC_DOMAIN}"}'
    ${output} =    Run node command    api-cli run module/${managed_id}/get-configuration
    &{config} =    Evaluate    json.loads($output)    json
    Should Be Equal    ${config.oidc_mode}    ns8
    Should Be Equal    ${config.oidc_client_id}    ${managed_id}
    Should Be Equal    ${config.oidc_issuer_url}    https://${KEYCLOAK_HOST}/realms/${OIDC_DOMAIN}
    Should Be Equal    ${config.oidc_callback_path}    /plugin-api/sso/callback
    Dictionary Should Not Contain Key    ${config}    oidc_client_secret
    Run node command    runagent -m ${managed_id} termix-refresh-sso
    ${login} =    Wait Until Keyword Succeeds    60s    3s    Run node command
    ...    curl -kfSs --resolve ${MANAGED_HOST}:443:127.0.0.1 https://${MANAGED_HOST}/users/auth/oidc/start
    Should Contain    ${login}    ${KEYCLOAK_HOST}
    Should Contain    ${login}    %2Fplugin-api%2Fsso%2Fcallback
    Run node command
    ...    curl -kfSs --resolve ${MANAGED_HOST}:443:127.0.0.1 https://${MANAGED_HOST}/users/auth/methods | jq -e '(.methods | any(.id=="password")) and ([.methods[] | select(.id=="oidc") | .instances[] | select(.autoStart != true)] | length == 1)' >/dev/null
    Run node command
    ...    api-cli run module/${managed_id}/configure-module --data '{"host":"${MANAGED_HOST}","http2https":true,"lets_encrypt":false,"oidc_mode":"ns8","oidc_provider":"${uuid}","oidc_domain":"${OIDC_DOMAIN}","oidc_allow_password_login":false,"oidc_silent_login":true}'
    Wait Until Keyword Succeeds    60s    3s    Run node command
    ...    curl -kfSs --resolve ${MANAGED_HOST}:443:127.0.0.1 https://${MANAGED_HOST}/users/auth/methods | jq -e '(.methods | all(.id!="password")) and ([.methods[] | select(.id=="oidc") | .instances[] | select(.autoStart == true)] | length == 1)' >/dev/null
    Run node command    runagent -m ${managed_id} termix-restore-password-login
    Wait Until Keyword Succeeds    60s    3s    Run node command
    ...    curl -kfSs --resolve ${MANAGED_HOST}:443:127.0.0.1 https://${MANAGED_HOST}/users/auth/methods | jq -e '(.methods | any(.id=="password")) and ([.methods[] | select(.id=="oidc") | .instances[] | select(.autoStart != true)] | length == 1)' >/dev/null

Take screenshots
    [Tags]    ui
    Import Library    Browser
    New Browser    chromium    headless=True
    New Context    ignoreHTTPSErrors=True
    Login to cluster-admin
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}
    Wait For Elements State    iframe >>> h2 >> text="Status"    visible    timeout=10s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/1._Status.png
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}?page=settings
    Wait For Elements State    iframe >>> h2 >> text="Settings"    visible    timeout=10s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/2._Settings.png
    Close Browser

Check if termix is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
