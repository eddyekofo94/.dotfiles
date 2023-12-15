if gh auth status >/dev/null 2>&1; then
  echo "gh is logged in"
  echo "$FZF_COMMON_OPTIONS"
  # ln -s $(which gh) /usr/bin/gh
fi
