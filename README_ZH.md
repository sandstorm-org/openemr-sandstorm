# OpenEMR Sandstorm 部署與開發指南

本專案將 OpenEMR 7.0.3 封裝成 Sandstorm app，並額外提供給 Gateway / 預約精靈使用的 HTTP API：

- `GET /apis/get_available_slots.php`：查詢可預約時段。
- `POST /apis/confirm_appointment.php`：建立 calendar-only 線上預約 event。

本文以 `vagrant-spk` 為唯一操作入口。不要在一般流程中直接使用 `vagrant ssh`；如果需要進 VM，使用 `vagrant-spk vm ssh`。

## 重要觀念

### Sandstorm grain

Sandstorm 會把每個 app instance 稱為 grain。每個 grain 有自己的 `/var` 狀態，例如 OpenEMR database、documents、site config。

### build / setup / launcher 的差異

這三個腳本的時機不同，這是本專案最容易踩到的地方：

| 檔案                     | 何時執行                    | 用途                                                   |
| ------------------------ | --------------------------- | ------------------------------------------------------ |
| `.sandstorm/build.sh`    | `vagrant-spk dev/pack` 時   | 編譯工具程式。                                         |
| `.sandstorm/setup.sh`    | VM/app build 或重新安裝時   | 安裝 OpenEMR、套 patch、把 custom API 複製進 OpenEMR。 |
| `.sandstorm/launcher.sh` | 每次 grain 啟動或 resume 時 | 啟動 MariaDB、套 idempotent migration、啟動 Apache。   |

`setup.sh` 不是每次 `vagrant-spk dev` 或 grain 啟動都會重跑。若你新增了 `apis/confirm_appointment.php` 這類需要複製到 OpenEMR document root 的檔案，但 VM 裡的 `/opt/openemr-7.0.3/openemr/apis/` 還是舊內容，pack 出來的 `.spk` 也會缺檔，實際呼叫時會得到 HTTP 404。

## 專案結構

```text
openemr-sandstorm/
  .sandstorm/
    sandstorm-pkgdef.capnp   Sandstorm package manifest
    setup.sh                 安裝 OpenEMR、套 patch、安裝 custom API
    launcher.sh              grain runtime entrypoint
    environment              共用路徑與版本變數
  apis/
    get_available_slots.php
    confirm_appointment.php
  sql/
    create_database.sql
    initial_data.sql
    sandstorm.sql
    sandstorm_calendar_category.sql
    seed_test_schedules.sql
  patches/
    apache2-*.patch
    mariadb-*.patch
    openemr-7.0.3/
  test/api/
    test_http_api.ts
```

## 第一次啟動開發環境

在 `openemr-sandstorm/` 專案根目錄執行：

```powershell
vagrant-spk vm up
vagrant-spk dev
```

然後開啟：

```text
http://local.sandstorm.io:6090
```

`vagrant-spk vm up` 會建立 VM 並準備 Sandstorm 開發環境。`vagrant-spk dev` 會啟動 Sandstorm dev server 與 app grain。

## 進入 VM 或 grain

進入 VM：

```powershell
vagrant-spk vm ssh
```

進入正在跑的 grain：

```powershell
vagrant-spk enter-grain
```

如果 `enter-grain` 問你要進哪個 grain，選正在運行的 OpenEMR grain。

## 修改 custom API 後的同步方式

custom API 原始檔在 repo：

```text
apis/get_available_slots.php
apis/confirm_appointment.php
```

OpenEMR 實際服務的檔案位置在 VM / package build 產物：

```text
/opt/openemr-7.0.3/openemr/apis/
```

如果只修改 `apis/*.php`，但沒有重新跑 `setup.sh`，請手動同步到 VM：

```powershell
vagrant-spk vm ssh
```

在 VM 裡執行：

```bash
sudo mkdir -p /opt/openemr-7.0.3/openemr/apis
sudo cp /opt/app/apis/get_available_slots.php /opt/openemr-7.0.3/openemr/apis/get_available_slots.php
sudo cp /opt/app/apis/confirm_appointment.php /opt/openemr-7.0.3/openemr/apis/confirm_appointment.php
ls -l /opt/openemr-7.0.3/openemr/apis/
exit
```

如果你改的是 `.sandstorm/setup.sh`、OpenEMR patches、系統套件或 Apache/MariaDB 設定，建議重新 provision / 重建 VM，而不是只手動複製單一檔案。

完整重建開發 VM：

```powershell
# 這會刪除 dev VM 內的狀態；只在你確定可以重建時使用。
vagrant-spk vm destroy
vagrant-spk vm up
vagrant-spk dev
```

## 建置與部署

### 建置前檢查

建置 `.spk` 前請確認：

1. `.sandstorm/sandstorm-pkgdef.capnp` 的 `appVersion` 和 `appMarketingVersion` 已遞增。
2. VM 中檔案是否更新，ex: `/opt/openemr-7.0.3/openemr/apis/confirm_appointment.php`。
3. HTTP API preflight 通過，不再出現 404。

#### 1.版本規則：
- `appVersion` 是 Sandstorm 判斷更新用的整數；同一個 app ID 每次正式上傳新版都要比已上傳版本大。
- `appMarketingVersion` 只是人看得懂的版本名稱，例如 `7.0.3-patch3`。
- 如果你還沒把目前的 `appVersion = 2` / `7.0.3-patch2` 上傳過，就不要先 bump 到 3；直接 pack 目前版本即可。

#### 2.確認 VM 內檔案：

詳見 [**修改 custom API 後的同步方式**]。

#### 3.執行 API preflight

先從 Sandstorm UI 的 OpenEMR grain 取得 API token。可用 top bar key icon 取得。

然後在 repo 根目錄執行：

```powershell
npx tsx test/api/test_http_api.ts `
  --host "https://api-XXXXX.your-sandstorm.example.com" `
  --token "YOUR_API_TOKEN"
```

這個測試預設會先用空 JSON POST 到 `/apis/confirm_appointment.php`。預期結果：

- HTTP 400：endpoint 存在，只是 body 缺必要欄位，代表 preflight 通過。
- HTTP 404：endpoint 沒有安裝到 OpenEMR grain，請先同步 API 或重建 VM，不要 pack。

如只想測 slots、暫時跳過 confirm endpoint preflight：

```powershell
npx tsx test/api/test_http_api.ts `
  --host "https://api-XXXXX.your-sandstorm.example.com" `
  --token "YOUR_API_TOKEN" `
  --skip-confirm-probe
```

執行 destructive confirm 測試

`--confirm` 會真的建立一筆 OpenEMR calendar event，請只在測試 grain 使用：

```powershell
npx tsx test/api/test_http_api.ts `
  --host "https://api-XXXXX.your-sandstorm.example.com" `
  --token "YOUR_API_TOKEN" `
  --from "2026-06-18" `
  --to "2026-06-24" `
  --confirm
```

它會驗證：

1. 找到一個 available slot。
2. POST `/apis/confirm_appointment.php` 建立 appointment。
3. 回傳 `OE-<eventId>`。
4. 再查同 provider/date，該 slot 不再出現。
5. 再 POST 同 slot，應回 409 `slot_unavailable`。

### 打包 pack `.spk`

確認以上檢查通過後再 pack：

```powershell
vagrant-spk pack openemr.spk
```

如果這次有新增 API 或 migration，請不要沿用舊的 `openemr.spk`。

### 上傳到 Sandstorm

1. 登入 Sandstorm server。
2. 打開 Admin / Apps 的 Upload App。
3. 上傳新的 `openemr.spk`。
4. 建立新的 OpenEMR grain，或更新後重啟既有 grain。
5. 用 API preflight 再驗一次 `confirm_appointment.php`。

## HTTP API

### `GET /apis/get_available_slots.php`

查詢指定日期範圍內的可用預約時段。

Query parameters：

| 參數       | 型別         | 必填 | 說明               |
| ---------- | ------------ | ---- | ------------------ |
| `from`     | `YYYY-MM-DD` | 否   | 起始日期。         |
| `to`       | `YYYY-MM-DD` | 否   | 結束日期。         |
| `provider` | integer      | 否   | 指定 provider id。 |

範例：

```bash
curl -H "Authorization: Bearer YOUR_API_TOKEN" \
  "https://api-XXXXX.your-sandstorm.example.com/apis/get_available_slots.php?from=2026-06-18&to=2026-06-24"
```

### `POST /apis/confirm_appointment.php`

建立 calendar-only appointment event。v1 不建立 `patient_data`，病人姓名、生日、就診原因會寫入 calendar event 的 `pc_hometext`。

Request：

```json
{
  "slot": {
    "date": "2026-06-18",
    "startTime": "09:00:00",
    "endTime": "09:30:00",
    "duration": 30,
    "providerId": 101
  },
  "appointmentInformation": {
    "person": {
      "firstName": "Jane",
      "lastName": "Doe",
      "dateOfBirth": "1990-01-02"
    },
    "reasonForAppointment": "Annual wellness check"
  },
  "preferences": {
    "languages": ["en"],
    "doctorGender": "any"
  }
}
```

Success：

```json
{
  "status": "success",
  "data": {
    "eventId": 123,
    "appointmentReference": "OE-123"
  }
}
```

Slot conflict：

```json
{
  "status": "error",
  "code": "slot_unavailable",
  "message": "This appointment slot is no longer available."
}
```

## 測試資料

可在 dev grain 內載入測試排班：

```powershell
vagrant-spk enter-grain
```

在 grain 裡執行：

```bash
mysql -u openemr -popenemr openemr < /opt/app/sql/seed_test_schedules.sql
exit
```

載入後可用 `test/api/test_http_api.ts` 查 slots 或跑 `--confirm`。

## 常見問題

### `confirm_appointment.php` 回 HTTP 404

原因通常是新 API 檔沒有被安裝到 OpenEMR document root。

檢查：

```powershell
vagrant-spk vm ssh
```

在 VM 裡：

```bash
ls -l /opt/openemr-7.0.3/openemr/apis/confirm_appointment.php
```

若不存在，請同步：

```bash
sudo mkdir -p /opt/openemr-7.0.3/openemr/apis
sudo cp /opt/app/apis/confirm_appointment.php /opt/openemr-7.0.3/openemr/apis/confirm_appointment.php
```

然後重新跑 API preflight。若要部署到遠端 Sandstorm，請重新 pack 並上傳新版 `.spk`。

### 我可以用 `vagrant ssh` 嗎？

本專案文件統一使用 `vagrant-spk vm ssh`。`vagrant ssh` 是底層 Vagrant 指令，只有在你很清楚目前工作目錄與 VM 狀態時才適合使用。為避免混淆，請優先使用 `vagrant-spk`。

### 修改 `.sandstorm/setup.sh` 後為什麼沒有生效？

`setup.sh` 不是 grain 每次啟動都會跑。它主要在 app build/provision 階段安裝 OpenEMR 與 patch。若你改了 setup 安裝步驟，請重新 provision/build VM，或手動把受影響檔案同步到 `/opt/openemr-7.0.3/openemr/`。

### 修改 SQL migration 後既有 grain 會套用嗎？

`launcher.sh` 每次 grain 啟動都會執行：

```bash
mysql openemr < /opt/app/sql/sandstorm_calendar_category.sql
```

這個 migration 是 idempotent，使用 `INSERT IGNORE`，可重複執行。若你新增其他 migration，也應採用同樣的 idempotent 風格。

## Windows 注意事項

Shell scripts、patches、SQL 建議保持 LF line endings。若在 Windows 開發，建議：

```powershell
git config core.autocrlf input
```

如果 shell script 在 VM 裡出現奇怪錯誤，先檢查是否被轉成 CRLF。

## 參考

- OpenEMR: https://www.open-emr.org/
- Sandstorm docs: https://docs.sandstorm.io/
- vagrant-spk: https://docs.sandstorm.io/en/latest/vagrant-spk/
