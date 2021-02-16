provider azurerm {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.product}-${var.env}"
  location = var.location

  tags = var.common_tags
}

module "key-vault" {
  source              = "git@github.com:hmcts/cnp-module-key-vault?ref=master"
  product             = var.product
  env                 = var.env
  tenant_id           = var.tenant_id
  object_id           = var.jenkins_AAD_objectId
  resource_group_name = azurerm_resource_group.rg.name

  # dcd_platformengineering group object ID
  product_group_object_id    = "c36eaede-a0ae-4967-8fed-0a02960b1370"
  common_tags                = var.common_tags
  create_managed_identity    = true
}

resource "azurerm_key_vault_secret" "AZURE_APPINSIGHTS_KEY" {
  name         = "AppInsightsInstrumentationKey"
  value        = azurerm_application_insights.appinsights.instrumentation_key
  key_vault_id = module.key-vault.key_vault_id
}

resource "azurerm_application_insights" "appinsights" {
  name                = "${var.product}-appinsights-${var.env}"
  location            = var.appinsights_location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"

  tags = var.common_tags

  lifecycle {
    ignore_changes = [
      # Ignore changes to appinsights as otherwise upgrading to the Azure provider 2.x
      # destroys and re-creates this appinsights instance
      application_type,
    ]
  }
}

resource "azurerm_monitor_action_group" "Ndiv44" {
  name                = "CriticalAlertsAction"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "p0action"

  email_receiver {
    name          = "sendtoadmin"
    email_address = "damon.green@hmcts.net"
  }


  logic_app_receiver {
    name                    = "Nfdiv-URL"
    resource_id             = "subscriptions/1c4f0704-a29e-403d-b719-b90c34ef14c9/resourcegroups/nfdiv-demo/providers/Microsoft.Logic/workflows/Nfdiv-URL/logicApp"
    callback_url            = "https://prod-00.uksouth.logic.azure.com:443/workflows/92968083557f446bb6acff64ea3afa69/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=FWSXTSNydGuxnZy9q_34_QDp1IIsZeP8yRdpCmLOKc8"
    use_common_alert_schema = false
  }

}