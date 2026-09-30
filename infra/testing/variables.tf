variable "project_id" {
  description = "Test project that hosts the GDE-Niño test environment (never hard-code it in the repo)."
  type        = string
}

variable "bq_location" {
  description = "BigQuery location; US to sit with WeatherNext linked datasets and public datasets."
  type        = string
  default     = "US"
}

variable "gcs_location" {
  description = "Location for test buckets (us-central1: next to ARCO-ERA5, cheapest, Always Free)."
  type        = string
  default     = "us-central1"
}

variable "pilot_tenants" {
  description = "Pilot institutions simulated as tenant datasets in the test project."
  type        = map(string)
  default = {
    mit     = "Ministerio de Infraestructura y Transporte (mit.gob.ec)"
    otavalo = "GAD Municipal de Otavalo (otavalo.gob.ec)"
    ecu911  = "Servicio Integrado de Seguridad ECU 911 (ecu911.gob.ec)"
  }
}

variable "secret_ids" {
  description = "Secret containers created empty; people add versions (never CI)."
  type        = list(string)
  default     = ["ewds-api-key", "cds-api-token", "typesafe-api-key", "floodforecasting-api-key", "earthdata-credentials", "copernicusmarine-credentials"]
}

variable "labels" {
  description = "Labels applied to every resource."
  type        = map(string)
  default     = { app = "ectwin", env = "test" }
}
