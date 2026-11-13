# rest4sftp

Puente entre una API REST y servidores **SFTP / FTP / FTPS**.

Escrito originalmente en Kotlin por Asad, Tom y Uberto
([uberto/rest4sftp](https://github.com/uberto/rest4sftp)).

> **Nota de este fork (klima-open-source):** este fork agrega soporte de
> **FTPS explícito (FTP sobre TLS)** mediante un nuevo modo `--ftps`, reactiva
> el plugin `application` de Gradle para volver a generar un ejecutable, corrige
> el `Dockerfile` para que construya sobre una imagen de JDK mantenida, e incluye
> una colección de API lista para usar con [Bruno](https://www.usebruno.com/) en
> la carpeta [`bruno/`](bruno/).

---

# Resumen: cómo funciona

`rest4sftp` **traduce llamadas HTTP (REST) en operaciones de archivos** sobre un
servidor FTP, FTPS o SFTP remoto.

```
  Cliente HTTP            rest4sftp                 Servidor remoto
  (curl, Bruno)  ──REST──►  (este puente)  ──FTP/FTPS/SFTP──►  (tu FTP)
```

El cliente hace una petición HTTP normal al puente. En **cada petición**, el
puente lee los datos de conexión al servidor remoto desde los **headers HTTP**
(`FTP-Host`, `FTP-Port`, `FTP-User`, `FTP-Password`), se conecta al servidor
remoto, ejecuta la operación (listar, descargar, subir, borrar) y devuelve el
resultado. El puente **no guarda credenciales**: viajan en cada petición.

El **protocolo** (FTP plano, FTPS o SFTP) se elige al arrancar el servidor con un
argumento de línea de comandos:

| Argumento | Protocolo | Puerto por defecto |
|-----------|-----------|--------------------|
| `--sftp`  | SFTP (sobre SSH)                 | 22 |
| `--ftp`   | FTP plano (sin cifrar)           | 21 |
| `--ftps`  | **FTPS explícito (FTP sobre TLS)** | — (indícalo con `FTP-Port`) |

Otros argumentos: `--port <n>` (puerto HTTP del puente, por defecto 8080),
`--timeout <segundos>` (por defecto 60) y `-v` (modo verboso).

---

# Instalación y ejecución

## Opción A — Docker (recomendada)

No hace falta instalar Java ni Gradle en tu máquina; el `Dockerfile` construye
todo dentro de la imagen y arranca el puente en el puerto 8080 del contenedor.

```bash
git clone https://github.com/klima-open-source/rest4sftp-ftps.git
cd rest4sftp-ftps
docker build -t rest4sftp:local .

# Arranca el puente en 127.0.0.1:9990 (elige el modo según tu servidor):
docker run -d --name rest4sftp -p 127.0.0.1:9990:8080/tcp rest4sftp:local --ftps
```

Útiles:

```bash
docker logs -f rest4sftp     # ver logs
docker stop rest4sftp        # detener
docker start rest4sftp       # volver a arrancar
```

## Opción B — Docker Compose

Crea un `docker-compose.yml`:

```yaml
services:
  rest4sftp:
    build: .
    ports:
      - "127.0.0.1:9990:8080"
    command: --ftps
```

Y levántalo:

```bash
docker compose up -d
```

## Opción C — Compilar y ejecutar directamente

Requiere **JDK 11** (el wrapper de Gradle 6.7.1 no es compatible con Java 17+).

```bash
git clone https://github.com/klima-open-source/rest4sftp-ftps.git
cd rest4sftp-ftps
./gradlew clean installDist
build/install/rest4sftp/bin/rest4sftp --ftps --port 8080
```

---

# Cómo usarlo (ejemplos con curl)

Suponiendo que el puente corre en `http://localhost:9990`:

```bash
# Listar el contenido de la carpeta "Upload" en un servidor SFTP
curl -i -X GET http://localhost:9990/folder/Upload \
  -H "FTP-Host:ftp.myserver.com" -H "FTP-Port:22" \
  -H "FTP-User:johnsmith" -H "FTP-Password:****"

# Subir myfile.ext a la carpeta "Upload"
curl -i -X PUT --data-binary @myfile.ext http://localhost:9990/file/Upload/myfile.ext \
  -H "FTP-Host:ftp.myserver.com" -H "FTP-Port:22" \
  -H "FTP-User:johnsmith" -H "FTP-Password:****"

# Descargar myfile.ext desde la carpeta "Upload"
curl -i -X GET http://localhost:9990/file/Upload/myfile.ext \
  -H "FTP-Host:ftp.myserver.com" -H "FTP-Port:22" \
  -H "FTP-User:johnsmith" -H "FTP-Password:****" -o descargado.ext
```

### Ejemplo contra un servidor FTPS (TLS)

Para servidores que exigen TLS, arranca el puente con `--ftps` y usa el puerto
del servidor FTPS (p. ej. 210). El puente cifra el canal de datos
automáticamente (`PBSZ 0` + `PROT P`):

```bash
docker run -d --name rest4sftp -p 127.0.0.1:9990:8080/tcp rest4sftp:local --ftps

curl -i -X GET http://localhost:9990/folder/MI_CARPETA \
  -H "FTP-Host:mi.servidor-ftps.com" -H "FTP-Port:210" \
  -H "FTP-User:usuario" -H "FTP-Password:****"
```

---

# Probar con Bruno

La carpeta [`bruno/`](bruno/) contiene una colección lista para usar con
[Bruno](https://www.usebruno.com/) con los cuatro endpoints:

1. Abre Bruno → **Open Collection** → selecciona la carpeta `bruno/`.
2. Arriba a la derecha, selecciona el entorno **Local**.
3. En el entorno **Local**, completa las variables de conexión:
   `ftp_host`, `ftp_port`, `ftp_user` y `ftp_password` (esta última se guarda
   como **secreto** de Bruno, fuera del repositorio).
4. Abre un request (p. ej. *01 - List Folder*) y pulsa **Send**.

Variables del entorno:

| Variable | Qué es |
|----------|--------|
| `base_url` | URL del puente `rest4sftp` (p. ej. `http://127.0.0.1:9990`) |
| `ftp_host` / `ftp_port` | Host y puerto del servidor remoto |
| `ftp_user` / `ftp_password` | Credenciales del servidor remoto |
| `folder` / `file_path` | Carpeta o archivo remoto sobre el que operar |

> El repositorio **no incluye credenciales reales**: las variables traen
> placeholders y la contraseña se guarda en el almacén de secretos de Bruno.

---

# Referencia de la API

## Operaciones sobre carpetas

### `GET /folder/{nombre_carpeta}`

Devuelve el contenido de la carpeta remota como `application/json; charset=utf8`.

- `401` si las credenciales del servidor en los headers son inválidas.
- `404` si la carpeta no existe.

## Operaciones sobre archivos

### `GET /file/{ruta/al/archivo}`

Devuelve el contenido del archivo como `application/octet-stream`.

- `401` si las credenciales son inválidas.
- `404` si la ruta no existe.

### `PUT /file/{ruta/al/archivo}`

Sube un archivo. El contenido va como **datos crudos en el cuerpo** de la
petición. Si el archivo ya existe en el servidor remoto, se sobrescribe.

- `200` si se subió correctamente.
- `400` si hubo un problema con el contenido o la ruta.
- `401` si las credenciales son inválidas.

### `DELETE /file/{ruta/al/archivo}`

Borra un archivo del servidor remoto.

- `200` si se borró correctamente.
- `400` si hubo un problema con la ruta.
- `401` si las credenciales son inválidas.

## Headers de la petición

Obligatorios:

* `FTP-Host`: hostname o IP del servidor remoto.
* `FTP-Port`: puerto del servidor remoto (por defecto 21 para FTP, 22 para SFTP).

Y, para las credenciales, **una** de estas dos formas:

* `FTP-User` + `FTP-Password`: usuario y contraseña de la cuenta en el servidor
  remoto, **o**
* `Authorization`: un header de Basic Auth (RFC 7617) con usuario y contraseña.

---

# Diseño del código

- El punto de entrada es `com.ubertob.rest4sftp.main.MainKt`.
- El servidor HTTP (http4k) vive en `com.ubertob.rest4sftp.http.RestfulServer`.
- Cada protocolo implementa la interfaz `SimpleRemoteClient`:
  - `ApacheCommonsFtpClient` → FTP y **FTPS** (parámetro `secure`), usando
    Apache Commons Net.
  - `SshJSftpClient` → SFTP, usando SSHJ.

---

# Licencia

Apache License 2.0 (ver [`LICENSE`](LICENSE)), heredada del proyecto original
[uberto/rest4sftp](https://github.com/uberto/rest4sftp).
