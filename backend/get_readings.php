<?php
require_once 'config.php';

header('Content-Type: application/json');

// Use Malaysia time even in PHP logic
date_default_timezone_set("Asia/Kuala_Lumpur");

try {
    // Get current local time
    $now = new DateTime("now", new DateTimeZone("Asia/Kuala_Lumpur"));
    $oneHourAgo = $now->sub(new DateInterval("PT1H"))->format("Y-m-d H:i:s");

    $stmt = $pdo->prepare("
        SELECT id, device_id, temperature, humidity, alert, 
               DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS timestamp
        FROM readings
        WHERE created_at >= :one_hour_ago
        ORDER BY created_at ASC
    ");
    $stmt->execute([
        ':one_hour_ago' => $oneHourAgo,
    ]);

    $readings = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'status' => 'success',
        'count' => count($readings),
        'data' => $readings
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
