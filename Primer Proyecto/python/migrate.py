import os
import sys
import mysql.connector
from mysql.connector import Error


def main() -> None:
    try:
        connection = mysql.connector.connect(
            host="mysql",
            port=3306,
            database=os.getenv("MYSQL_DATABASE"),
            user=os.getenv("MYSQL_USER"),
            password=os.getenv("MYSQL_PASSWORD"),
        )

        if connection.is_connected():
            cursor = connection.cursor()
            cursor.execute("SELECT VERSION()")
            version = cursor.fetchone()[0]

            print("Conexión exitosa a MySQL.")
            print(f"Versión del servidor: {version}")

            cursor.close()
            connection.close()

    except Error as error:
        print(f"Error al conectar con MySQL: {error}")
        sys.exit(1)


if __name__ == "__main__":
    main()
