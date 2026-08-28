output "external_ips" {
  description = "Public IP addresses"

  value = {
    for name, vm in yandex_compute_instance.vm :
    name => vm.network_interface[0].nat_ip_address
  }
}

output "internal_ips" {
  description = "Private IP addresses"

  value = {
    for name, vm in yandex_compute_instance.vm :
    name => vm.network_interface[0].ip_address
  }
}

output "mediawiki_url" {
  description = "MediaWiki load balancer URL"

  value = "http://${yandex_compute_instance.vm["lb-01"].network_interface[0].nat_ip_address}"
}

output "zabbix_url" {
  description = "Zabbix web interface URL"

  value = "http://${yandex_compute_instance.vm["zabbix-01"].network_interface[0].nat_ip_address}"
}
