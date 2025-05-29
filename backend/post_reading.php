<?php
require_once 'config.php';

// Set timezone explicitly
date_default_timezone_set("Asia/Kuala_Lumpur");

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $device_id   = $_POST['device_id'] ?? '';
    $temperature = $_POST['temperature'] ?? '';
    $humidity    = $_POST['humidity'] ?? '';
    $alert       = $_POST['alert'] ?? '0';

    if ($device_id === '' || $temperature === '' || $humidity === '') {
        http_response_code(400);
        echo "Missing parameters.";
        exit;
    }

    // Round current local time to nearest lower 10s
    $rounded = time() - (time() % 10);
    $created_at = date("Y-m-d H:i:s", $rounded);

    $stmt = $pdo->prepare("
        INSERT INTO readings (device_id, temperature, humidity, alert, created_at)
        VALUES (:device_id, :temperature, :humidity, :alert, :created_at)
        ON DUPLICATE KEY UPDATE
            temperature = VALUES(temperature),
            humidity = VALUES(humidity),
            alert = VALUES(alert)
    ");

    $stmt->execute([
        ':device_id' => $device_id,
        ':temperature' => $temperature,
        ':humidity' => $humidity,
        ':alert' => $alert,
        ':created_at' => $created_at,
    ]);

    echo "OK";
} else {
    http_response_code(405);
    echo "Method not allowed.";
}
