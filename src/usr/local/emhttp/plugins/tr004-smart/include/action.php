<?php
/* tr004-smart: Aktionen der Einstellungsseite. Nur feste Befehle, keine freien Parameter.
 * Unraid prueft das csrf_token bei POST-Anfragen selbst. */
$allowed = [
  'check'   => 'list',
  'enable'  => 'enable',
  'disable' => 'disable',
  'read'    => 'read --full',
];
$action = $_POST['action'] ?? '';
if (!isset($allowed[$action])) { http_response_code(400); echo "unknown action"; exit; }
exec('/usr/local/sbin/tr004-smart '.$allowed[$action].' 2>&1', $out, $rc);
header('Content-Type: text/plain; charset=utf-8');
echo implode("\n", $out);
echo "\n(exit $rc)\n";
