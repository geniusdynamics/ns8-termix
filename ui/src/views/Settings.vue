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
            <cv-text-input
              :label="$t('settings.termix_fqdn')"
              placeholder="termix.example.org"
              v-model.trim="host"
              class="mg-bottom"
              :invalid-message="$t(error.host)"
              :disabled="loading.getConfiguration || loading.configureModule"
              ref="host"
            >
            </cv-text-input>
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
              <!-- advanced options -->
            <cv-accordion ref="accordion" class="maxwidth mg-bottom">
              <cv-accordion-item :open="toggleAccordion[0]">
                <template slot="title">{{ $t("settings.advanced") }}</template>
                <template slot="content">
                  <h4 class="mg-bottom">{{ $t("settings.oidc_settings") }}</h4>
                  <cv-text-input
                    :label="$t('settings.oidc_client_id')"
                    v-model.trim="oidcClientId"
                    class="mg-bottom"
                    :invalid-message="$t(error.oidc_client_id)"
                    :disabled="loading.getConfiguration || loading.configureModule"
                    ref="oidcClientId"
                  >
                  </cv-text-input>
                  <cv-text-input
                    :label="$t('settings.oidc_client_secret')"
                    type="password"
                    v-model.trim="oidcClientSecret"
                    class="mg-bottom"
                    :invalid-message="$t(error.oidc_client_secret)"
                    :disabled="loading.getConfiguration || loading.configureModule"
                    ref="oidcClientSecret"
                  >
                  </cv-text-input>
                  <cv-text-input
                    :label="$t('settings.oidc_issuer_url')"
                    placeholder="https://auth.example.com"
                    v-model.trim="oidcIssuerUrl"
                    class="mg-bottom"
                    :invalid-message="$t(error.oidc_issuer_url)"
                    :disabled="loading.getConfiguration || loading.configureModule"
                    ref="oidcIssuerUrl"
                  >
                  </cv-text-input>
                  <cv-text-input
                    :label="$t('settings.oidc_authorization_url')"
                    placeholder="https://auth.example.com/authorize"
                    v-model.trim="oidcAuthorizationUrl"
                    class="mg-bottom"
                    :invalid-message="$t(error.oidc_authorization_url)"
                    :disabled="loading.getConfiguration || loading.configureModule"
                    ref="oidcAuthorizationUrl"
                  >
                  </cv-text-input>
                  <cv-text-input
                    :label="$t('settings.oidc_token_url')"
                    placeholder="https://auth.example.com/token"
                    v-model.trim="oidcTokenUrl"
                    class="mg-bottom"
                    :invalid-message="$t(error.oidc_token_url)"
                    :disabled="loading.getConfiguration || loading.configureModule"
                    ref="oidcTokenUrl"
                  >
                  </cv-text-input>
                  <cv-text-input
                    :label="$t('settings.oidc_userinfo_url')"
                    placeholder="https://auth.example.com/userinfo"
                    v-model.trim="oidcUserinfoUrl"
                    class="mg-bottom"
                    :invalid-message="$t(error.oidc_userinfo_url)"
                    :disabled="loading.getConfiguration || loading.configureModule"
                    ref="oidcUserinfoUrl"
                  >
                  </cv-text-input>
                  <cv-text-input
                    :label="$t('settings.oidc_identifier_path')"
                    placeholder="sub"
                    v-model.trim="oidcIdentifierPath"
                    class="mg-bottom"
                    :invalid-message="$t(error.oidc_identifier_path)"
                    :disabled="loading.getConfiguration || loading.configureModule"
                    ref="oidcIdentifierPath"
                  >
                  </cv-text-input>
                  <cv-text-input
                    :label="$t('settings.oidc_name_path')"
                    placeholder="name"
                    v-model.trim="oidcNamePath"
                    class="mg-bottom"
                    :invalid-message="$t(error.oidc_name_path)"
                    :disabled="loading.getConfiguration || loading.configureModule"
                    ref="oidcNamePath"
                  >
                  </cv-text-input>
                  <cv-text-input
                    :label="$t('settings.oidc_scopes')"
                    placeholder="openid email profile"
                    v-model.trim="oidcScopes"
                    class="mg-bottom"
                    :invalid-message="$t(error.oidc_scopes)"
                    :disabled="loading.getConfiguration || loading.configureModule"
                    ref="oidcScopes"
                  >
                  </cv-text-input>
                </template>
              </cv-accordion-item>
            </cv-accordion>
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
      // OIDC fields
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
      
      // Load OIDC configuration
      this.oidcClientId = config.oidc_client_id || "";
      this.oidcClientSecret = config.oidc_client_secret || "";
      this.oidcIssuerUrl = config.oidc_issuer_url || "";
      this.oidcAuthorizationUrl = config.oidc_authorization_url || "";
      this.oidcTokenUrl = config.oidc_token_url || "";
      this.oidcUserinfoUrl = config.oidc_userinfo_url || "";
      this.oidcIdentifierPath = config.oidc_identifier_path || "sub";
      this.oidcNamePath = config.oidc_name_path || "name";
      this.oidcScopes = config.oidc_scopes || "openid email profile";

      this.loading.getConfiguration = false;
      this.focusElement("host");
    },
    validateConfigureModule() {
      this.clearErrors(this);

      let isValidationOk = true;
      if (!this.host) {
        this.error.host = "common.required";

        if (isValidationOk) {
          this.focusElement("host");
        }
        isValidationOk = false;
      }
      return isValidationOk;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusAlreadySet = false;

      for (const validationError of validationErrors) {
        const param = validationError.parameter;
        // set i18n error message
        this.error[param] = this.$t("settings." + validationError.error);

        if (!focusAlreadySet) {
          this.focusElement(param);
          focusAlreadySet = true;
        }
      }
    },
    async configureModule() {
      this.error.test_imap = false;
      this.error.test_smtp = false;
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
            oidc_client_id: this.oidcClientId,
            oidc_client_secret: this.oidcClientSecret,
            oidc_issuer_url: this.oidcIssuerUrl,
            oidc_authorization_url: this.oidcAuthorizationUrl,
            oidc_token_url: this.oidcTokenUrl,
            oidc_userinfo_url: this.oidcUserinfoUrl,
            oidc_identifier_path: this.oidcIdentifierPath,
            oidc_name_path: this.oidcNamePath,
            oidc_scopes: this.oidcScopes,
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
        console.error(`error creating task ${taskAction}`, err);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
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
