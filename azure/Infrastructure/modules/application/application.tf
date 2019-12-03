# Resource group for application(remove later when network works)
resource "azurerm_resource_group" "rg" {
  name     = "project-resources-group"
  location = "East US"
}

resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

# Storage for images - Storage blob
resource "azurerm_storage_account" "sa" {
  name                     = "projectstoracc"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  location                 = "${azurerm_resource_group.rg.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "BlobStorage"
  access_tier              = "Hot"
}

resource "azurerm_storage_container" "image-container" {
  name                  = "images"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  storage_account_name  = "${azurerm_storage_account.sa.name}"
  container_access_type = "private"
}

resource "azurerm_storage_blob" "object-storage" {
  name                   = "content.zip"
  resource_group_name    = "${azurerm_resource_group.rg.name}"
  storage_account_name   = "${azurerm_storage_account.sa.name}"
  storage_container_name = "${azurerm_storage_container.image-container.name}"
  type                   = "Block"
  #source                 = "local-content.zip"
}

# Storage for data - MySQL
resource "azurerm_mysql_server" "mysql-server-demo" {
  name                = "mysqlserver-${random_integer.ri.result}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  sku {
    name     = "B_Gen5_2"
    capacity = 2
    tier     = "Basic"
    family   = "Gen5"
  }

  storage_profile {
    storage_mb            = 5120
    backup_retention_days = 7
    geo_redundant_backup  = "Disabled"
  }

  administrator_login          = "mysqladminun"
  administrator_login_password = "Admin@123"
  version                      = "5.7"
  ssl_enforcement              = "Enabled"
}

resource "azurerm_mysql_database" "mysql-db" {
  name                = "mysqldb"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  server_name         = "${azurerm_mysql_server.mysql-server-demo.name}"
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

# Storage for token - CosmosDB
resource "azurerm_cosmosdb_account" "cosmos-db" {
    name                = "tfex-cosmos-db-${random_integer.ri.result}"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    offer_type          = "Standard"
    kind                = "GlobalDocumentDB"

    enable_automatic_failover = true

    consistency_policy {
        consistency_level       = "BoundedStaleness"
        max_interval_in_seconds = 301
        max_staleness_prefix    = 100001
    }

    geo_location {
        location          = "West US"
        failover_priority = 1
    }

    geo_location {
        prefix            = "tfex-cosmos-db-${random_integer.ri.result}-customid"
        location          = "${azurerm_resource_group.rg.location}"
        failover_priority = 0
    }
}

# Azure Functions
resource "azurerm_storage_account" "functionsa-demo" {
  name                     = "functionsa${random_integer.ri.result}"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  location                 = "${azurerm_resource_group.rg.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "asp" {
  name                = "azure-functions-service-plan"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "function" {
  name                      = "project-func"
  location                  = "${azurerm_resource_group.rg.location}"
  resource_group_name       = "${azurerm_resource_group.rg.name}"
  app_service_plan_id       = "${azurerm_app_service_plan.asp.id}"
  storage_connection_string = "${azurerm_storage_account.functionsa-demo.primary_connection_string}"
}