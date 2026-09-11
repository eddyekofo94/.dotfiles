# Handy

Tracked settings for the [Handy](https://handy.computer/) offline dictation app.
The configuration uses local Apple Intelligence cleanup and contains no API
credentials.

## Commands

```sh
./handy/verify.sh  # validate the tracked configuration and secret guard
./handy/status.sh  # compare live settings with the sanitized tracked copy
./handy/export.sh  # sanitize live settings into the repository
./handy/install.sh # install tracked settings while preserving live API keys
```

Quit Handy before running `export.sh` or `install.sh`. Relaunch it afterward.
`install.sh` refuses to replace live settings while Handy is running and writes
a timestamped backup under `.backups/handy/`.

## Workflow

1. Change and manually test one Handy preference.
2. Quit Handy and run `./handy/export.sh`.
3. Review `handy/settings_store.json`; API-key values must remain empty.
4. Run `./handy/verify.sh` and `./handy/status.sh`.
5. Commit only after both checks pass.

## Manual QA

Automated checks cannot exercise microphone, Accessibility, or Apple
Intelligence behavior. After installing or changing the configuration:

- Confirm `Option+Space` records and inserts Apple Intelligence-cleaned text.
- Confirm `Option+Shift+Space` records and inserts raw text.
- Confirm punctuation cleanup does not answer questions or change their meaning.
- Confirm Handy retains Microphone and Accessibility permission after relaunch.
- Confirm no OpenAI or other paid provider is selected.
