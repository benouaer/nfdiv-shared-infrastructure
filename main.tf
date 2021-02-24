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

resource "azurerm_monitor_action_group" "appinsights" {
  name                = "nfdiv-ag"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "nfdiv-p1"

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

resource "azurerm_application_insights_web_test" "appinsights" {
  name                    = "tf-test-appinsights-webtest"
  location                = var.appinsights_location
  resource_group_name     = azurerm_resource_group.rg.name
  application_insights_id = azurerm_application_insights.appinsights.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 60
  enabled                 = true
  geo_locations           = ["emea-se-sto-edge", "emea-ru-msa-edge"]

  configuration = <<XML
<WebTest Name="WebTest1" Id="ABD48585-0831-40CB-9069-682EA6BB3583" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="0" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale="">
  <Items>
    <Request Method="GET" Guid="a5f10126-e4cd-570d-961c-cea43999a200" Version="1.1" Url="https://apply-for-divorce.service.gov.uk/" ThinkTime="0" Timeout="300" ParseDependentRequests="True" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />
  </Items>
</WebTest>
XML

}
output "webtest_id" {
  value = azurerm_application_insights_web_test.appinsights.id
}

output "webtests_synthetic_id" {
  value = azurerm_application_insights_web_test.appinsights.synthetic_monitor_id
}

resource "azurerm_monitor_action_rule_action_group" "appinsights" {
  name                = "coded-rule"
  resource_group_name = azurerm_resource_group.rg.name
  action_group_id     = azurerm_monitor_action_group.appinsights.id
  enabled                 = true


  scope {
    type         = "ResourceGroup"
    resource_ids = [azurerm_resource_group.rg.id]
  }

  tags = {
    foo = "bar"
  }
}

resource "azurerm_application_insights_web_test" "appinsights-2" {
  name = "manual2-test"
  location = var.appinsights_location
  resource_group_name = azurerm_resource_group.rg.name
  application_insights_id = azurerm_application_insights.appinsights.id
  kind = "ping"
  frequency = 300
  timeout = 60
  enabled = true
  retry_enabled = true
  geo_locations = [
    "emea-se-sto-edge",
    "apac-sg-sin-azr",
    "us-il-ch1-azr",
    "emea-gb-db3-azr",
    "emea-ru-msa-edge"]

  configuration = "<WebTest Name=\"manual1-dg\" Id=\"2723c2f5-fa3a-4ac2-832c-8444bd8f8da5\" Enabled=\"True\"   CssProjectStructure=\"\"         CssIteration=\"\"         Timeout=\"120\"         WorkItemIds=\"\"         xmlns=\"http://microsoft.com/schemas/VisualStudio/TeamTest/2010\"         Description=\"\"         CredentialUserName=\"\"         CredentialPassword=\"\"         PreAuthenticate=\"True\"         Proxy=\"default\"         StopOnError=\"False\"         RecordedResultFile=\"\"         ResultsLocale=\"\">        <Items>        <Request         Method=\"GET\"         Guid=\"a5eb315b-d699-bdd6-e527-43120955cb86\"         Version=\"1.1\"         Url=\"http://www.google.com\"         ThinkTime=\"0\"         Timeout=\"120\"         ParseDependentRequests=\"False\"         FollowRedirects=\"True\"         RecordResult=\"True\"         Cache=\"False\"         ResponseTimeGoal=\"0\"         Encoding=\"utf-8\"         ExpectedHttpStatusCode=\"200\"         ExpectedResponseUrl=\"\"         ReportingName=\"\"         IgnoreHttpStatusCode=\"False\" />        </Items>        </WebTest>"
}


resource "azurerm_monitor_metric_alert" "appinsights" {
  name                = "nfdiv-metricalert1"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = azurerm_application_insights_web_test.appinsights
  description         = "Action will be triggered when count is less than 90%"

  application_insights_web_test_location_availability_criteria {
    web_test_id = azurerm_application_insights_web_test.appinsights.id
    component_id = azurerm_application_insights.appinsights.id
    failed_location_count = 2
  }

  action {
  action_group_id = azurerm_monitor_action_group.appinsights.id
  }
}
