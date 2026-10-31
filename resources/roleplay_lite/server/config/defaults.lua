LITE_CONFIG = {
    database = {
        connection = "host=127.0.0.1;port=3306;dbname=roleplay_lite",
        username = "roleplay_lite",
        password = "env:G1R_LITE_DB_PASSWORD",
        options = "charset=utf8mb4"
    },
    spawn = { x = 993.918, y = -564.841, z = 29.876, yaw = -171.5 },
    mine = { x = 993.918, y = -564.841, z = 29.876, radius = 5, ore = 1,
        minimumWaitMs = 1600, randomWaitMs = 1800, hitWindowMs = 1400, cooldownMs = 5000 },
    chatRange = 20,
    actionRange = 20,
    whisperRange = 4,
    shoutRange = 40,
    lookRange = 5,
    socialCooldownMs = 1000,
    maxChatBytes = 180
}
