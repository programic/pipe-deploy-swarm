BLA=22
BLA2=asd
BLA3=aa

bla() {
  if [[ -z "${BLA}" ]] || [[ -z "${BLA2}" ]] || [[ -z "${BLA4}" ]]; then
    return
  fi
  echo "KAK"
}

bla