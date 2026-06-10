# twilio-ios-voice-test

Twilio Voice SDKでiOSアプリからPSTNへ発信するPoCです。

## Local Settings

ローカル設定は以下に置きます。このファイルは`.gitignore`済みです。

```text
twilio-ios-voice-test/.env
```

設定名の一覧は[.env.example](twilio-ios-voice-test/.env.example)にあります。

最短のPoCでは、アプリ側でTwilio Voice Access Tokenを生成できます。

```dotenv
TOKEN_ENDPOINT=
DEFAULT_IDENTITY=ios_poc_user
DEFAULT_TO_NUMBER=+819012345678
CALLER_ID=+819012345678

ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
API_KEY_SID=SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
API_KEY_SECRET=xxxxxxxx
TWIML_APP_SID=APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

`TOKEN_ENDPOINT`を設定した場合は、従来どおりFunctionsなどの`/token`からAccess Tokenを取得します。空にした場合は、`.env`内の`ACCOUNT_SID`、`API_KEY_SID`、`API_KEY_SECRET`、`TWIML_APP_SID`からアプリ内でAccess Tokenを生成します。

`DEFAULT_TO_NUMBER`と`CALLER_ID`はE.164形式で指定します。

```text
090-1234-5678 -> +819012345678
03-1234-5678  -> +81312345678
```

## Twilio Side

アプリ内でAccess Tokenを生成する場合でも、TwiML Appと`/voice`は必要です。

TwiML App:

```text
Voice Request URL = https://xxxx.twil.io/voice
HTTP Method = POST
```

`/voice`側は、アプリから渡す`To`と`CallerId`を使って`<Dial><Number>`を返します。

```js
exports.handler = function(context, event, callback) {
  const response = new Twilio.twiml.VoiceResponse();
  const to = event.To || event.to;
  const callerId = event.CallerId || context.CALLER_ID;

  if (!to || !/^\+\d{8,15}$/.test(to)) {
    response.say("Invalid phone number.");
    response.hangup();
    return callback(null, response);
  }

  const dial = response.dial({ callerId });
  dial.number(to);
  callback(null, response);
};
```

Trialアカウントでは発信先もVerified済み番号に限定されます。
