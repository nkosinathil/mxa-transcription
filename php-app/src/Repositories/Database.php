<?php
/**
 * php-app/src/Repositories/Database.php
 * ----------------------------------------
 * PDO database connection singleton.
 *
 * Plain-language:
 *   Every repository class needs a database connection.  Instead of creating
 *   a new connection on every query, we create it once and reuse it.  This
 *   is called the singleton pattern.
 */

declare(strict_types=1);

namespace App\Repositories;

use App\Config\Config;
use PDO;
use PDOException;
use RuntimeException;

class Database
{
    private static ?PDO $instance = null;

    public static function connection(): PDO
    {
        if (self::$instance === null) {
            $host = Config::get('db.host');
            $port = Config::get('db.port');
            $name = Config::get('db.name');
            $user = Config::get('db.user');
            $pass = Config::get('db.pass');

            $dsn = "pgsql:host={$host};port={$port};dbname={$name}";

            try {
                self::$instance = new PDO($dsn, $user, $pass, [
                    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES   => false,
                ]);
            } catch (PDOException $e) {
                throw new RuntimeException('Database connection failed: ' . $e->getMessage());
            }
        }

        return self::$instance;
    }
}
