#!/usr/bin/env bash

set -eu

update_nginx_configuration() {
  local app=$1
  local nginx_config_template=$2
  local domain=$3
  local path=$4
  local deploy_path=$5

  sed --in-place "s@YNH_WWW_PATH@${path}@g" ${nginx_config_template}
  sed --in-place "s@YNH_WWW_ALIAS@${deploy_path}/@g" ${nginx_config_template}

  sudo cp ${nginx_config_template} /etc/nginx/conf.d/${domain}.d/${app}.conf
  sudo service nginx reload
}

download_file() {
  local url=$1
  local output_document=$2
  wget --no-verbose --output-document=${output_document} ${url}
}

check_file_integrity() {
  local file=$1
  local expected_checksum=$2

  echo "${expected_checksum} ${file}" | sha256sum --check --status \
    || ynh_die "Corrupt source!"
}

extract_archive() {
  local src_file=$1
  local deploy_path=$2

  sudo mkdir --parents ${deploy_path}
  sudo tar --extract --file=${src_file} --directory=${deploy_path} --overwrite --strip-components 1
  sudo chown --recursive root: $deploy_path
}

obtain_and_deploy_source() {
  local app_config=$1
  local deploy_path=$2
  local src_url=$(app_config_get $app_config "SOURCE_URL")
  local src_checksum=$(app_config_get $app_config "SOURCE_SUM")
  local src_file="/tmp/source.tar.gz"

  download_file $src_url $src_file
  check_file_integrity $src_file $src_checksum
  extract_archive $src_file $deploy_path
}

update_accessibility() {
  local app=$1
  local is_public=$2

  if [[ ${is_public:-0} -eq 1 ]]; then
    ynh_app_setting_set $app unprotected_uris "/"
    sudo yunohost app ssowatconf
  fi
}