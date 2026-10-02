<?php

/**
 * Home Assistant app glue. DokuWiki includes this file before anything else.
 * It is part of the app image (not your wiki data) and is replaced on update.
 *
 * 1. Ingress: Home Assistant serves the sidebar panel under a private prefix
 *    (/api/hassio_ingress/<token>/). The Supervisor strips that prefix before
 *    the request reaches nginx and reports it in the X-Ingress-Path header.
 *    We hand it to DokuWiki so every link, stylesheet, script and redirect is
 *    routed back through ingress. The URLs are kept host-relative so they work
 *    no matter how Home Assistant itself is reached (LAN, reverse proxy,
 *    Nabu Casa ...). nginx only sets HA_INGRESS=1 on the ingress listener,
 *    which accepts connections from the Supervisor alone.
 *
 * 2. First run: until the installer has written conf/local.php, visitors of
 *    doku.php are sent to install.php to create the admin account and ACLs.
 */

(static function (): void {
    $base = '/';

    $ingressPath = $_SERVER['HTTP_X_INGRESS_PATH'] ?? '';
    if (
        ($_SERVER['HA_INGRESS'] ?? '0') === '1'
        && preg_match('#^/api/hassio_ingress/[A-Za-z0-9_\-]+$#', $ingressPath) === 1
    ) {
        $base = $ingressPath . '/';
        if (!defined('DOKU_REL')) define('DOKU_REL', $base);
        if (!defined('DOKU_URL')) define('DOKU_URL', $base);
    }

    if (
        PHP_SAPI !== 'cli'
        && basename($_SERVER['SCRIPT_NAME'] ?? '') === 'doku.php'
        && !file_exists(dirname(__DIR__) . '/conf/local.php')
        && file_exists(dirname(__DIR__) . '/install.php')
    ) {
        header('Location: ' . $base . 'install.php', true, 302);
        exit;
    }
})();
