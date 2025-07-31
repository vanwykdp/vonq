provider "google" {
    credentials = file("C:\\devops\\vonq\\terraform\\GCP\\bb42-testing-8c8784bb822d.json")
    project = "bb42-testing"
    region = "europe-west1"
    zone = "europe-west1-b"
}