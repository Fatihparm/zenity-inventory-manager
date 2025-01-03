#!/bin/bash

# Zenity ile Basit Envanter Yönetim Sistemi
# Gerekli CSV dosyalarını kontrol eder ve oluşturur

echo "Proje başlatılıyor..."

# CSV dosyalarının kontrolü ve oluşturulması
function check_and_create_csv {
  local files=("depo.csv" "kullanici.csv" "log.csv")
  for file in "${files[@]}"; do
    if [ ! -f "$file" ]; then
      touch "$file"
      echo "$file dosyası oluşturuldu."
    fi
  done
}

check_and_create_csv

# Kullanıcı giriş ekranı
function login {
  zenity --forms --title="Giriş" --text="Kullanıcı Girişi" \
    --add-entry="Kullanıcı Adı" \
    --add-password="Parola" > login_info.txt

  local username=$(awk -F '|' '{print $1}' login_info.txt)
  local password=$(awk -F '|' '{print $2}' login_info.txt)

  # Kullanıcı doğrulama
  if grep -q "$username" kullanici.csv && grep -q "$password" kullanici.csv; then
    zenity --info --text="Hoş geldiniz, $username!"
    main_menu
  else
    zenity --error --text="Kullanıcı adı veya parola hatalı!"
    rm login_info.txt
    login
  fi
}

# Ana menü
function main_menu {
  local choice=$(zenity --list --title="Ana Menü" --column="İşlem" \
    "Ürün Ekle" "Ürün Listele" "Ürün Güncelle" "Ürün Sil" "Rapor Al" "Kullanıcı Yönetimi" "Program Yönetimi" "Çıkış")

  case "$choice" in
    "Ürün Ekle")
      add_product
      ;;
    "Ürün Listele")
      list_products
      ;;
    "Ürün Güncelle")
      update_product
      ;;
    "Ürün Sil")
      delete_product
      ;;
    "Rapor Al")
      generate_report
      ;;
    "Kullanıcı Yönetimi")
      user_management
      ;;
    "Program Yönetimi")
      program_management
      ;;
    "Çıkış")
      zenity --question --text="Çıkmak istediğinizden emin misiniz?" && exit 0
      ;;
  esac
}

# Ürün ekleme
function add_product {
  local input=$(zenity --forms --title="Ürün Ekle" --text="Yeni ürün bilgilerini girin:" \
    --add-entry="Ürün Adı" \
    --add-entry="Stok Miktarı" \
    --add-entry="Birim Fiyatı")

  local name=$(echo "$input" | awk -F '|' '{print $1}')
  local stock=$(echo "$input" | awk -F '|' '{print $2}')
  local price=$(echo "$input" | awk -F '|' '{print $3}')

  if [[ -z "$name" || -z "$stock" || -z "$price" || "$stock" -lt 0 || "$price" -lt 0 ]]; then
    zenity --error --text="Geçersiz giriş. Lütfen tüm alanları doğru doldurun."
    return
  fi

  local id=$(($(tail -n 1 depo.csv | awk -F ',' '{print $1}') + 1))
  echo "$id,$name,$stock,$price" >> depo.csv
  zenity --info --text="Ürün başarıyla eklendi."
}

# Ürün listeleme
function list_products {
  if [ ! -s depo.csv ]; then
    zenity --warning --text="Envanterde ürün bulunmamaktadır."
    return
  fi

  zenity --text-info --title="Ürün Listesi" --filename=<(awk -F ',' '{printf "Ürün ID: %s\nAdı: %s\nStok: %s\nFiyat: %s\n\n", $1, $2, $3, $4}' depo.csv)
}

# Ürün güncelleme
function update_product {
  local name=$(zenity --entry --title="Ürün Güncelle" --text="Güncellemek istediğiniz ürünün adını girin:")

  if ! grep -q "$name" depo.csv; then
    zenity --error --text="Belirtilen ürün bulunamadı."
    return
  fi

  local stock=$(zenity --entry --title="Stok Güncelle" --text="Yeni stok miktarını girin:")
  local price=$(zenity --entry --title="Fiyat Güncelle" --text="Yeni birim fiyatını girin:")

  if [[ -z "$stock" || -z "$price" || "$stock" -lt 0 || "$price" -lt 0 ]]; then
    zenity --error --text="Geçersiz giriş. Lütfen doğru değerler girin."
    return
  fi

  awk -F ',' -v name="$name" -v stock="$stock" -v price="$price" \
    'BEGIN {OFS=","} {if ($2 == name) $3 = stock; if ($2 == name) $4 = price} 1' depo.csv > tmp.csv && mv tmp.csv depo.csv

  zenity --info --text="Ürün başarıyla güncellendi."
}

# Ürün silme
function delete_product {
  local name=$(zenity --entry --title="Ürün Sil" --text="Silmek istediğiniz ürünün adını girin:")

  if ! grep -q "$name" depo.csv; then
    zenity --error --text="Belirtilen ürün bulunamadı."
    return
  fi

  zenity --question --text="Bu ürünü silmek istediğinizden emin misiniz?" || return

  awk -F ',' -v name="$name" 'BEGIN {OFS=","} $2 != name {print $0}' depo.csv > tmp.csv && mv tmp.csv depo.csv

  zenity --info --text="Ürün başarıyla silindi."
}

# Raporlama
function generate_report {
  local choice=$(zenity --list --title="Rapor Al" --column="Rapor Türü" \
    "Stokta Azalan Ürünler" "En Yüksek Stok Miktarına Sahip Ürünler")

  case "$choice" in
    "Stokta Azalan Ürünler")
      local threshold=$(zenity --entry --title="Eşik Değeri" --text="Eşik değerini girin:")
      awk -F ',' -v threshold="$threshold" 'BEGIN {print "Stokta Azalan Ürünler:"} $3 < threshold {print $2 " - Stok: " $3}' depo.csv | zenity --text-info --title="Stokta Azalan Ürünler"
      ;;
    "En Yüksek Stok Miktarına Sahip Ürünler")
      awk -F ',' 'BEGIN {print "En Yüksek Stok Miktarına Sahip Ürünler:"} {if ($3 > max) {max=$3; name=$2}} END {print name " - Stok: " max}' depo.csv | zenity --text-info --title="En Yüksek Stok Miktarı"
      ;;
  esac
}

# Kullanıcı yönetimi
function user_management {
  local choice=$(zenity --list --title="Kullanıcı Yönetimi" --column="İşlem" \
    "Yeni Kullanıcı Ekle" "Kullanıcıları Listele" "Kullanıcı Güncelle" "Kullanıcı Sil")

  case "$choice" in
    "Yeni Kullanıcı Ekle")
      local input=$(zenity --forms --title="Yeni Kullanıcı Ekle" --text="Kullanıcı bilgilerini girin:" \
        --add-entry="Kullanıcı Adı" \
        --add-password="Parola")
      local username=$(echo "$input" | awk -F '|' '{print $1}')
      local password=$(echo "$input" | awk -F '|' '{print $2}')
      echo "$username,$password" >> kullanici.csv
      zenity --info --text="Kullanıcı başarıyla eklendi."
      ;;
    "Kullanıcıları Listele")
      zenity --text-info --title="Kullanıcı Listesi" --filename=kullanici.csv
      ;;
    "Kullanıcı Güncelle")
      local username=$(zenity --entry --title="Kullanıcı Güncelle" --text="Güncellemek istediğiniz kullanıcının adını girin:")
      local new_password=$(zenity --entry --title="Yeni Parola" --text="Yeni parolayı girin:")
      awk -F ',' -v username="$username" -v new_password="$new_password" 'BEGIN {OFS=","} {if ($1 == username) $2 = new_password} 1' kullanici.csv > tmp.csv && mv tmp.csv kullanici.csv
      zenity --info --text="Kullanıcı başarıyla güncellendi."
      ;;
    "Kullanıcı Sil")
      local username=$(zenity --entry --title="Kullanıcı Sil" --text="Silmek istediğiniz kullanıcının adını girin:")
      awk -F ',' -v username="$username" 'BEGIN {OFS=","} $1 != username {print $0}' kullanici.csv > tmp.csv && mv tmp.csv kullanici.csv
      zenity --info --text="Kullanıcı başarıyla silindi."
      ;;
  esac
}

# Program yönetimi
function program_management {
  local choice=$(zenity --list --title="Program Yönetimi" --column="İşlem" \
    "Diskte Kapladığı Alan" "Diske Yedek Alma" "Hata Kayıtlarını Görüntüleme")

  case "$choice" in
    "Diskte Kapladığı Alan")
      local disk_usage=$(du -sh . | awk '{print $1}')
      zenity --info --text="Dosyaların kapladığı toplam alan: $disk_usage"
      ;;
    "Diske Yedek Alma")
      local backup_file="backup_$(date +%Y%m%d%H%M%S).tar.gz"
      tar -czf "$backup_file" depo.csv kullanici.csv log.csv
      zenity --info --text="Yedekleme tamamlandı. Dosya: $backup_file"
      ;;
    "Hata Kayıtlarını Görüntüleme")
      if [ ! -s log.csv ]; then
        zenity --warning --text="Hata kaydı bulunmamaktadır."
      else
        zenity --text-info --title="Hata Kayıtları" --filename=log.csv
      fi
      ;;
  esac
}

echo "Proje altyapısı oluşturuldu. Giriş sistemini başlatıyorum..."
login
