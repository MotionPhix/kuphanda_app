<?php

/**
 * Entry point for the cPanel document root.
 *
 * The document root at /home/kuphanda/public_html/app.kuphanda.com sits
 * outside the project, so the __DIR__.'/..' paths from Laravel's stock
 * public/index.php cannot reach the application. The checkout is addressed
 * explicitly instead. deploy/deploy.sh copies this file into place on every
 * deploy, so keep the two in step if the layout ever changes.
 */

declare(strict_types=1);

use Illuminate\Foundation\Application;
use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

$base = '/home/kuphanda/kuphanda/phanda_api';

// Determine if the application is in maintenance mode...
if (file_exists($maintenance = $base.'/storage/framework/maintenance.php')) {
    require $maintenance;
}

// Register the Composer autoloader...
require $base.'/vendor/autoload.php';

// Bootstrap Laravel and handle the request...
/** @var Application $app */
$app = require_once $base.'/bootstrap/app.php';

$app->handleRequest(Request::capture());
