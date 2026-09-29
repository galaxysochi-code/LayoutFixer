#!/bin/zsh
# Создаёт постоянный самоподписанный сертификат для подписи LayoutFixer.
#
# Зачем: по умолчанию программа подписывается временной подписью, которая меняется при каждой
# сборке. macOS считает её новой программой и каждый раз просит заново выдать доступ к клавиатуре.
# С постоянным сертификатом подпись не меняется, и разрешение сохраняется между обновлениями.
#
# Запускать вручную: ./scripts/make-signing-cert.sh
# macOS спросит пароль — он нужен, чтобы добавить сертификат в вашу связку ключей и разрешить ему
# подписывать программы. Сертификат остаётся только на этом компьютере.

set -e
NAME="${1:-LayoutFixer Local}"
DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT

if security find-certificate -c "$NAME" >/dev/null 2>&1; then
  echo "Сертификат «$NAME» уже есть в связке ключей."
else
  echo "Создаю сертификат «$NAME»…"
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$DIR/key.pem" -out "$DIR/cert.pem" \
    -subj "/CN=$NAME" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
  openssl pkcs12 -export -out "$DIR/id.p12" -inkey "$DIR/key.pem" -in "$DIR/cert.pem" -passout pass: 2>/dev/null

  echo "Добавляю в связку ключей (потребуется пароль)…"
  security import "$DIR/id.p12" -k ~/Library/Keychains/login.keychain-db -P "" -A
  echo "Разрешаю сертификату подписывать программы (потребуется пароль)…"
  security add-trusted-cert -p codeSign -k ~/Library/Keychains/login.keychain-db "$DIR/cert.pem"
fi

echo
echo "Готово. Теперь собирайте так:"
echo "  SIGN_IDENTITY=\"$NAME\" ./build.sh"
echo
echo "Чтобы это стало постоянным, добавьте строку в ~/.zshrc:"
echo "  export SIGN_IDENTITY=\"$NAME\""
echo
echo "Доступ к клавиатуре после этого выдайте один раз заново — дальше он сохранится."
