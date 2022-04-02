

if [ "$(cat last_response 2>/dev/null)" != "OK"]; then
  exit 1
fi

exit 0
