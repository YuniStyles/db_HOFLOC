
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║           BD_Hofloc_Gestion — SISTEMA GANADERO HOFLOC.SA                ║
-- ║           Versión 3.0 — Revisión, Correcciones y Objetos Completos      ║
-- ║           MySQL 8.0+  •  InnoDB  •  utf8mb4_unicode_ci                  ║
-- ║                                                                          ║
-- ║  CORRECCIONES APLICADAS EN v2:                                           ║
-- ║  [C1] tbl_colaborador reactivada (estaba comentada, rompía FKs en       ║
-- ║       tbl_registro_sanitario y tbl_evento_reproductivo)                  ║
-- ║  [C2] tbl_auditoria_alerta: FK id_alerta → tbl_alerta corregida         ║
-- ║       (la tabla auditora ahora SÍ apunta a su tabla origen)             ║
-- ║  [C3] SELECT COUNT(*) de información_schema eliminado del script        ║
-- ║  [C4] Todos los triggers, vistas y SPs añadidos en bloques separados    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 0: CONFIGURACIÓN DEL ENTORNO
--  Crea la base de datos, el usuario y asigna permisos.
--  Ejecuta este bloque como root/admin antes de continuar.
-- ════════════════════════════════════════════════════════════════════════════

CREATE DATABASE IF NOT EXISTS BD_vaquitas
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

-- Usuario dedicado para la aplicación (cambia la contraseña en producción)
CREATE USER IF NOT EXISTS 'usuario1'@'localhost' IDENTIFIED BY 'contrasena1';
GRANT ALL PRIVILEGES ON BD_vaquitas.* TO 'usuario1'@'localhost';
FLUSH PRIVILEGES;

USE BD_vaquitas;

SET FOREIGN_KEY_CHECKS = 0;

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 1: SEGURIDAD — ROLES, USUARIOS, COLABORADORES
-- ════════════════════════════════════════════════════════════════════════════

-- Catálogo de roles del sistema
CREATE TABLE tbl_rol (
    id_rol         INT AUTO_INCREMENT PRIMARY KEY,
    nombre_rol     VARCHAR(50)  NOT NULL UNIQUE,
    descripcion    VARCHAR(255) NULL,
    activo         BOOLEAN      NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB COMMENT='Catálogo de roles de acceso al sistema';

-- Usuarios con acceso al sistema
CREATE TABLE tbl_usuario (
    id_usuario      INT AUTO_INCREMENT PRIMARY KEY,
    usuario         VARCHAR(50)  NOT NULL UNIQUE,
    email           VARCHAR(120) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    nombre_completo VARCHAR(120) NOT NULL,
    telefono        VARCHAR(25)  NULL,
    id_rol          INT          NOT NULL,
    estado          ENUM('activo','inactivo','bloqueado') NOT NULL DEFAULT 'activo',
    ultimo_login    DATETIME     NULL,
    fecha_creacion  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modif     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_usuario_rol FOREIGN KEY (id_rol)
        REFERENCES tbl_rol(id_rol) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_usuario_estado (estado),
    INDEX idx_usuario_email  (email)
) ENGINE=InnoDB COMMENT='Credenciales y accesos del sistema';

-- Tabla coloborador
--      la referenciaban con FK → error al crear esas tablas.
CREATE TABLE tbl_colaborador (
    id_colaborador INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario     INT          NULL,
    nombre         VARCHAR(120) NOT NULL,
    telefono       VARCHAR(25)  NULL,
    correo         VARCHAR(120) NULL,
    id_rol         INT          NOT NULL,
    estado         ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',
    notas          TEXT         NULL,
    fecha_ingreso  DATE         NOT NULL DEFAULT (CURRENT_DATE),
    fecha_creacion TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_colab_usuario FOREIGN KEY (id_usuario)
        REFERENCES tbl_usuario(id_usuario) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_colab_rol FOREIGN KEY (id_rol)
        REFERENCES tbl_rol(id_rol) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_colab_estado (estado)
) ENGINE=InnoDB COMMENT='Personal de campo, veterinarios y técnicos';

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 2: CATÁLOGOS BASE
-- ════════════════════════════════════════════════════════════════════════════

-- Razas bovinas
CREATE TABLE tbl_raza (
    id_raza     INT AUTO_INCREMENT PRIMARY KEY,
    nombre_raza VARCHAR(60) NOT NULL UNIQUE,
    proposito   ENUM('Carne','Lecheria','Doble Propósito') NOT NULL DEFAULT 'Doble Propósito',
    descripcion VARCHAR(255) NULL,
    activo      BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB COMMENT='Catálogo de razas bovinas';

-- Procedencia del animal
CREATE TABLE tbl_procedencia (
    id_procedencia INT AUTO_INCREMENT PRIMARY KEY,
    nombre         VARCHAR(60)  NOT NULL UNIQUE,
    descripcion    VARCHAR(255) NULL
) ENGINE=InnoDB COMMENT='Origen del animal: nacido, comprado, donado';

-- Mangas / lotes / corrales
CREATE TABLE tbl_manga (
    id_manga        INT AUTO_INCREMENT PRIMARY KEY,
    numero_manga    INT NOT NULL UNIQUE,
    nombre          VARCHAR(60) NOT NULL,
    funcion         ENUM(
                        'Ordeño','Cría', 'Reproducción','Preparto',
                        'Novillas','Ceba','Lactancia','Machos Levante','Atención Veterinaria'
                     ) NOT NULL,
    capacidad_max   INT NOT NULL DEFAULT 0,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_manga_funcion (funcion)
) ENGINE=InnoDB
COMMENT='Lotes, corrales y mangas del establecimiento';
-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 3: MÓDULO DE CAUSAS DINÁMICAS
--  ─────────────────────────────────────────────────────────────────────────
--  El usuario escribe libremente la causa en un campo de texto.
--  El sistema busca si ya existe (por descripcion, insensible a mayúsculas
--  gracias al cotejamiento unicode_ci) y reutiliza el id o inserta uno nuevo.
--  Esto garantiza: sin duplicados, sin ENUM rígido, historial limpio.
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE tbl_causa (
    id_causa         INT AUTO_INCREMENT PRIMARY KEY,
    causa_principal  ENUM(
                        'Digestivo','Diarrea','Otros'
                      ) NOT NULL,
    detalle_causa    VARCHAR(255) NULL,
    activo           BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_causa_principal (causa_principal)
) ENGINE=InnoDB
COMMENT='Registro de causas sanitarias con opción de detalle personalizado';

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 4: ANIMALES — TABLA PADRE + TABLAS DE DETALLES (1:N)
--  ─────────────────────────────────────────────────────────────────────────
--  CAMBIO ARQUITECTÓNICO CENTRAL:
--  En v1 las tablas tbl_vaca / tbl_toro / tbl_ternero tenían id_animal como
--  PK y FK simultáneamente → relación 1:1 rígida, sin historial posible.
--
--  En v2 las tablas de detalles tienen su PROPIA PK autoincremental y una
--  FK (id_animal) que apunta al padre → relación 1:N.
--  Un animal puede tener múltiples filas de detalle a lo largo del tiempo.
--  La columna 'activo' (o 'es_vigente') identifica el registro en curso.
--  Los anteriores quedan como historial auditado.
--
--  Ventajas:
--  • Se puede ver la evolución del estado reproductivo de una vaca mes a mes.
--  • Al promover un ternero no se borra/mueve ninguna fila; solo se crea una
--    nueva en la tabla hija de destino y se cierra la de origen.
--  • Cada cambio de estado queda trazado con fecha y usuario responsable.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Tabla PADRE: datos comunes a todo animal ─────────────────────────────────
CREATE TABLE tbl_animal (
    id_animal           INT AUTO_INCREMENT PRIMARY KEY, -- ¡Faltaba la PK!
    id_procedencia      INT NULL,
    id_raza             INT NOT NULL,                    -- ¡Faltaba declarar!
    id_manga_actual     INT NULL,                    -- ¡Faltaba declarar!
    trazabilidad        VARCHAR(20) NOT NULL,        -- ¡Faltaba declarar!
    tipo_animal         ENUM('Vaca','Toro','Ternero') NOT NULL, -- ¡Faltaba declarar!
    sexo                ENUM('M','F') NOT NULL,      -- ¡Faltaba declarar!
    arete               VARCHAR(50) NOT NULL,        -- ¡Faltaba declarar!
    fecha_nacimiento    DATE NOT NULL,
    fecha_ingreso       DATE NOT NULL DEFAULT (CURRENT_DATE),
    peso_actual_kg      DECIMAL(7,2) NULL,
    estado_animal       ENUM('Activo','Inactivo', 'Vendido','Fallecido') NOT NULL DEFAULT 'Activo',
    foto_url            VARCHAR(255) NULL,
    observaciones       TEXT NULL,
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_trazabilidad
        CHECK (trazabilidad REGEXP '^[0-9]{6}$'),
    CONSTRAINT fk_animal_raza
        FOREIGN KEY (id_raza) REFERENCES tbl_raza(id_raza)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_animal_manga 
        FOREIGN KEY (id_manga_actual) REFERENCES tbl_manga(id_manga)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_animal_procedencia FOREIGN KEY (id_procedencia)
        REFERENCES tbl_procedencia(id_procedencia)
        ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_animal_tipo (tipo_animal), 
    INDEX idx_animal_sexo (sexo),
    INDEX idx_animal_estado (estado_animal),
    INDEX idx_animal_arete (arete)
) ENGINE=InnoDB COMMENT='Tabla principal de animales';

-- ── Tabla de DETALLES: VACA (1:N — historial reproductivo y productivo) ───────
CREATE TABLE tbl_vaca_detalle (
    id_vaca_detalle     BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal           INT NOT NULL,
    estado_ordeno       ENUM('Activo','Inactivo') NOT NULL DEFAULT 'Activo',
    estado_reproductivo ENUM('Preñada','Parida','Vacía','Seca','Lactando') NOT NULL DEFAULT 'Vacía',
    fecha_inicio        DATE NOT NULL DEFAULT (CURRENT_DATE),
    fecha_fin           DATE NULL,
    es_vigente          BOOLEAN NOT NULL DEFAULT TRUE,
    observaciones       TEXT NULL,
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_vacadet_animal FOREIGN KEY (id_animal) REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_vaca_animal (id_animal),
    INDEX idx_vaca_vigente (id_animal, es_vigente)
) ENGINE=InnoDB COMMENT='Historial reproductivo y productivo de vacas';

-- ── Tabla de DETALLES: TORO (1:N — historial de uso reproductivo) ─────────────
CREATE TABLE tbl_toro_detalle (
    id_toro_detalle      BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal            INT NOT NULL,
    tipo_uso             ENUM('Semental','Ceba','Levante') NOT NULL DEFAULT 'Semental',
    activo_reproduccion  BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_inicio_reprod  DATE NULL,
    libido_evaluacion    ENUM('Alta','Media','Baja','Sin evaluar') NOT NULL DEFAULT 'Sin evaluar',
    es_vigente           BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_inicio         DATE NOT NULL DEFAULT (CURRENT_DATE),
    fecha_fin            DATE NULL,
    id_usuario_registro  INT NULL,
    fecha_creacion       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_torodet_animal
        FOREIGN KEY (id_animal) REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_torodet_usuario
        FOREIGN KEY (id_usuario_registro) REFERENCES tbl_usuario(id_usuario)
        ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_torodet_animal (id_animal),
    INDEX idx_torodet_vigente (id_animal, es_vigente)
) ENGINE=InnoDB COMMENT='Información general del toro';

/*Por Monta Natural*/
CREATE TABLE tbl_toro_monta_natural (
    id_monta_natural     BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_toro_detalle      BIGINT NOT NULL,
    num_montas_acumuladas INT NOT NULL DEFAULT 0,
    fecha_inicio_monta   DATE NULL,
    observaciones        TEXT NULL,
    fecha_creacion       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_monta_toro FOREIGN KEY (id_toro_detalle) REFERENCES tbl_toro_detalle (id_toro_detalle)
        ON UPDATE CASCADE ON DELETE CASCADE,
    UNIQUE KEY uq_monta_toro (id_toro_detalle)
) ENGINE=InnoDB COMMENT='Datos reproductivos para monta natural';

/*Inseminacion*/
CREATE TABLE tbl_toro_inseminacion (
    id_inseminacion      BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_toro_detalle      BIGINT NOT NULL,
    codigo_envase        CHAR(6) NOT NULL,
    observaciones        TEXT NULL,
    activo               BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_insem_toro FOREIGN KEY (id_toro_detalle) REFERENCES tbl_toro_detalle (id_toro_detalle)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_codigo_envase CHECK (codigo_envase REGEXP '^[0-9]{6}$'),
    UNIQUE KEY uq_codigo_envase (codigo_envase),
    INDEX idx_insem_toro (id_toro_detalle)
) ENGINE=InnoDB COMMENT='Registro de envases/pajillas de inseminación';

-- ── Tabla de DETALLES: TERNERO (1:N — seguimiento desde nacimiento) ───────────
CREATE TABLE tbl_ternero_detalle (
    id_ternero_detalle    BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal             INT NOT NULL,
    id_madre              INT NULL,
    id_padre              INT NULL,
    peso_nacimiento_kg    DECIMAL(6,2) NULL,
    peso_destete_kg       DECIMAL(6,2) NULL,
    ganancia_diaria_kg    DECIMAL(5,3) NULL,
    estado_lactancia      ENUM('Lactante','Pre-destete','Destetado') NOT NULL DEFAULT 'Lactante',
    fecha_destete         DATE NULL,
    observaciones         TEXT NULL,
    es_vigente            BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_inicio          DATE NOT NULL DEFAULT (CURRENT_DATE),
    fecha_fin             DATE NULL,
    fecha_creacion        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_ternero_animal FOREIGN KEY (id_animal) REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ternero_madre FOREIGN KEY (id_madre) REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_ternero_padre FOREIGN KEY (id_padre) REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE SET NULL, 
    INDEX idx_ternero_animal (id_animal),
    INDEX idx_ternero_vigente (id_animal, es_vigente)
) ENGINE=InnoDB COMMENT='Seguimiento y crecimiento de terneros';

-- Tabla de Auditoria 
CREATE TABLE tbl_animal_auditoria (
    id_auditoria         BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal            INT NOT NULL,
    accion               ENUM('Cambio Estado', 'Muerte','Venta','Actualización') NOT NULL,
    estado_anterior      VARCHAR(50) NULL,
    estado_nuevo         VARCHAR(50) NULL,
    motivo               VARCHAR(255) NULL,
    observaciones        TEXT NULL,
    fecha_evento         DATE NOT NULL,
    fecha_creacion       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_audit_animal FOREIGN KEY (id_animal) REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_audit_animal (id_animal)
) ENGINE=InnoDB COMMENT='Auditoría de cambios importantes de animales';

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 5: MOVIMIENTOS ENTRE MANGAS (historial)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE tbl_movimiento_manga (
    id_movimiento BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal INT NOT NULL,
    id_manga_origen INT NULL,
    id_manga_destino INT NOT NULL,
    motivo VARCHAR(255) NULL,
    fecha_movimiento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario INT NULL,
    observaciones TEXT NULL,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_mov_animal FOREIGN KEY (id_animal)
        REFERENCES tbl_animal (id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_mov_origen FOREIGN KEY (id_manga_origen)
        REFERENCES tbl_manga (id_manga)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_mov_destino FOREIGN KEY (id_manga_destino)
        REFERENCES tbl_manga (id_manga)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_mov_usuario FOREIGN KEY (id_usuario)
        REFERENCES tbl_usuario (id_usuario)
        ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_mov_fecha (fecha_movimiento),
    INDEX idx_mov_animal (id_animal),
    INDEX idx_mov_destino (id_manga_destino)
)  ENGINE=INNODB COMMENT='Historial de movimientos individuales de animales entre mangas';

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 6: PESAJE
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE tbl_pesaje (
    id_pesaje         BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal         INT          NOT NULL,
    fecha_pesaje      DATE         NOT NULL,
    hora_pesaje       TIME         NULL,
    peso_kg           DECIMAL(7,2) NOT NULL CHECK (peso_kg > 0),
    -- tipo_alimentacion ENUM('Mixto','Estabulado','Pastoreo') NOT NULL DEFAULT 'Pastoreo', (No Se verifica)
    observaciones     TEXT NULL,
    id_usuario        INT  NULL,
    fecha_creacion    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pesaje_animal  FOREIGN KEY (id_animal)
        REFERENCES tbl_animal(id_animal) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_pesaje_usuario FOREIGN KEY (id_usuario)
        REFERENCES tbl_usuario(id_usuario) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_pesaje_fecha        (fecha_pesaje),
    INDEX idx_pesaje_animal_fecha (id_animal, fecha_pesaje)
) ENGINE=InnoDB COMMENT='Registro histórico de pesajes por animal';

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 7: PRODUCCIÓN DE LECHE (ORDEÑO)
-- ════════════════════════════════════════════════════════════════════════════

/*Tabla produccion de Leche - Para manejar el calculo de produccion*/
CREATE TABLE tbl_produccion_leche (
    id_produccion        BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal            INT NOT NULL,
    fecha_ordeno         DATE NOT NULL,
    litros_manana        DECIMAL(6,2) NOT NULL DEFAULT 0,
    litros_tarde         DECIMAL(6,2) NOT NULL DEFAULT 0,
    total_litros         DECIMAL(6,2) GENERATED ALWAYS AS (litros_manana + litros_tarde) STORED,
    observaciones        TEXT NULL,
    fecha_creacion       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_prod_animal FOREIGN KEY (id_animal) REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    UNIQUE KEY uq_prod_fecha (id_animal, fecha_ordeno)
) ENGINE=InnoDB COMMENT='Producción diaria de leche';

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 8: GESTIÓN SANITARIA
-- ════════════════════════════════════════════════════════════════════════════

-- Catálogo de vacunas y medicamentos
CREATE TABLE tbl_producto_sanitario (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    tipo ENUM('Vacuna', 'Antibiótico', 'Antiparasitario', 'Vitamina', 'Hormonal', 'Otro') NOT NULL,
    unidad_medida VARCHAR(20) NULL,
    descripcion VARCHAR(255) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_prod_san (nombre , tipo)
)  ENGINE=INNODB COMMENT='Catálogo de productos veterinarios';

-- Registro maestro del evento sanitario (cabecera)
CREATE TABLE tbl_registro_sanitario (
    id_registro_san BIGINT AUTO_INCREMENT PRIMARY KEY,
    tipo_aplicacion ENUM('Individual', 'Masivo') NOT NULL DEFAULT 'Individual',
    categoria ENUM('Tratamiento', 'Vacunación', 'Mastitis') NOT NULL,
    sub_tipo VARCHAR(80) NULL,
    proposito ENUM('Preventivo', 'Correctivo') NULL,
    id_producto INT NULL,
    dosis_valor DECIMAL(8 , 2 ) NULL,
    dosis_unidad ENUM('ml', 'cc', 'mg', 'g', 'uds') NULL,
    fecha_aplicacion DATE NOT NULL,
    hora_aplicacion TIME NULL,
    repeticion ENUM('Única', 'Diaria', 'Semanal', 'Personalizada') NOT NULL DEFAULT 'Única',
    intervalo_dias INT NULL,
    duracion_dias INT NULL,
    id_causa INT NULL,
    responsable VARCHAR(120) NULL,
    notas TEXT NULL,
    id_veterinario INT NULL,
    id_usuario INT NULL,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_san_producto FOREIGN KEY (id_producto)
        REFERENCES tbl_producto_sanitario (id_producto)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_san_causa FOREIGN KEY (id_causa)
        REFERENCES tbl_causa (id_causa)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_san_vet FOREIGN KEY (id_veterinario)
        REFERENCES tbl_colaborador (id_colaborador)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_san_usuario FOREIGN KEY (id_usuario)
        REFERENCES tbl_usuario (id_usuario)
        ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_san_fecha (fecha_aplicacion),
    INDEX idx_san_categoria (categoria)
)  ENGINE=INNODB COMMENT='Cabecera principal de registros sanitarios';

-- Detalle: animales aplicados por cada evento (1:N)
CREATE TABLE tbl_registro_sanitario_animal (
    id_detalle BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_registro_san BIGINT NOT NULL,
    id_animal INT NOT NULL,
    estado_aplicacion ENUM('Pendiente', 'Aplicado', 'Cancelado') NOT NULL DEFAULT 'Pendiente',
    fecha_real_aplicacion DATETIME NULL,
    observacion VARCHAR(155) NULL,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rsa_registro FOREIGN KEY (id_registro_san)
        REFERENCES tbl_registro_sanitario (id_registro_san)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_rsa_animal FOREIGN KEY (id_animal)
        REFERENCES tbl_animal (id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    UNIQUE KEY uq_rsa (id_registro_san , id_animal),
    INDEX idx_rsa_animal (id_animal)
)  ENGINE=INNODB COMMENT='Animales incluidos en cada evento sanitario';

-- Detalle especial mastitis (diagnóstico por cuarto mamario)
CREATE TABLE tbl_mastitis_cuartos (
    id_mastitis BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_registro_san BIGINT NOT NULL,
    id_animal INT NOT NULL,
    cuarto_ad ENUM('Sana', 'Subclínica', 'Leve', 'Moderada') NOT NULL DEFAULT 'Sana',
    cuarto_pd ENUM('Sana', 'Subclínica', 'Leve', 'Moderada') NOT NULL DEFAULT 'Sana',
    cuarto_ai ENUM('Sana', 'Subclínica', 'Leve', 'Moderada') NOT NULL DEFAULT 'Sana',
    cuarto_pi ENUM('Sana', 'Subclínica', 'Leve', 'Moderada') NOT NULL DEFAULT 'Sana',
    notas_diagnostico TEXT NULL,
    en_tratamiento BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_mast_registro FOREIGN KEY (id_registro_san)
        REFERENCES tbl_registro_sanitario (id_registro_san)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_mast_animal FOREIGN KEY (id_animal)
        REFERENCES tbl_animal (id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_mastitis_animal (id_animal)
)  ENGINE=INNODB COMMENT='Diagnóstico mastitis por cuarto mamario';

CREATE TABLE tbl_programacion_sanitaria (
    id_programacion BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_registro_san BIGINT NOT NULL,
    fecha_programada DATETIME NOT NULL,
    estado ENUM('Pendiente', 'Aplicado', 'Vencido', 'Cancelado') NOT NULL DEFAULT 'Pendiente',
    observaciones TEXT NULL,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_prog_san FOREIGN KEY (id_registro_san)
        REFERENCES tbl_registro_sanitario (id_registro_san)
        ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_prog_fecha (fecha_programada),
    INDEX idx_prog_estado (estado)
)  ENGINE=INNODB COMMENT='Cronograma de aplicaciones sanitarias';

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 9: REPRODUCCIÓN
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE tbl_evento_reproductivo (
    id_evento_rep        BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal            INT  NOT NULL,    -- vaca o hembra participante
    tipo_evento          ENUM('Inseminación Artificial','Monta Natural','Palpación',
                              'Celo','Parto','Aborto','Secado') NOT NULL,
    fecha_evento         DATE NOT NULL,
    hora_evento          TIME NULL,
    -- IA
    numero_pajilla       VARCHAR(40)  NULL,
    raza_semen           VARCHAR(60)  NULL,
    proveedor_semen      VARCHAR(120) NULL,
    -- Monta Natural
    id_toro              INT          NULL,
    -- Palpación
    fase_palpacion       ENUM('Fase 1','Fase 2') NULL,
    resultado_palp       ENUM('Preñada','Vacía','Preñez provisional',
                              'Preñez confirmada','Sin evaluar') NULL,
    -- Resultado
    estado_resultado     ENUM('Programado','Realizado','Cancelado') NOT NULL DEFAULT 'Realizado',
    fecha_estimada_parto DATE         NULL,
    id_causa             INT          NULL,   -- FK → tbl_causa (ej: aborto por...)
    observaciones        TEXT         NULL,
    id_veterinario       INT          NULL,
    id_usuario           INT          NULL,
    fecha_creacion       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rep_animal     FOREIGN KEY (id_animal)
        REFERENCES tbl_animal(id_animal) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_rep_toro       FOREIGN KEY (id_toro)
        REFERENCES tbl_animal(id_animal) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_rep_causa      FOREIGN KEY (id_causa)
        REFERENCES tbl_causa(id_causa) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_rep_vet        FOREIGN KEY (id_veterinario)
        REFERENCES tbl_colaborador(id_colaborador) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_rep_usuario    FOREIGN KEY (id_usuario)
        REFERENCES tbl_usuario(id_usuario) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_rep_fecha  (fecha_evento),
    INDEX idx_rep_tipo   (tipo_evento),
    INDEX idx_rep_animal (id_animal)
) ENGINE=InnoDB COMMENT='Registro de eventos reproductivos (IA, monta, parto, aborto, etc.)';

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 10: MORTALIDAD
--  ─────────────────────────────────────────────────────────────────────────
--  CAMBIO: La columna 'causa' deja de ser ENUM rígido.
--  Ahora es una FK hacia tbl_causa, donde el usuario puede registrar
--  cualquier descripción de texto libre desde el formulario.
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE tbl_mortalidad (
    id_mortalidad BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal INT NOT NULL UNIQUE,
    id_causa INT NOT NULL,
    fecha_muerte DATE NOT NULL,
    fecha_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacion TEXT NULL,
    id_usuario INT NULL,
    CONSTRAINT fk_mort_animal FOREIGN KEY (id_animal)
        REFERENCES tbl_animal (id_animal)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_mort_causa FOREIGN KEY (id_causa)
        REFERENCES tbl_causa (id_causa)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_mort_usuario FOREIGN KEY (id_usuario)
        REFERENCES tbl_usuario (id_usuario)
        ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_mort_fecha (fecha_muerte),
    INDEX idx_mort_causa (id_causa)
)  ENGINE=INNODB COMMENT='Registro histórico de mortalidad animal';

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 11: BAJA DE ANIMAL (VENTA / RETIRO / DONACIÓN)
--  ─────────────────────────────────────────────────────────────────────────
--  Nueva tabla: cubre las salidas no relacionadas con muerte.
--  También usa id_causa → motivo de venta/descarte como texto libre.
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE tbl_baja_animal (
    id_baja        BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal      INT          NOT NULL UNIQUE,
    tipo_baja      ENUM('Venta','Donación','Descarte','Retiro','Otro') NOT NULL DEFAULT 'Venta',
    id_causa       INT          NULL,     -- FK → tbl_causa (motivo de la salida)
    fecha_baja     DATE         NOT NULL,
    precio_venta   DECIMAL(12,2) NULL,    -- solo si tipo_baja = 'Venta'
    comprador      VARCHAR(120) NULL,
    observacion    TEXT         NULL,
    id_usuario     INT          NULL,
    fecha_creacion TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_baja_animal  FOREIGN KEY (id_animal)
        REFERENCES tbl_animal(id_animal) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_baja_causa   FOREIGN KEY (id_causa)
        REFERENCES tbl_causa(id_causa) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_baja_usuario FOREIGN KEY (id_usuario)
        REFERENCES tbl_usuario(id_usuario) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_baja_fecha (fecha_baja),
    INDEX idx_baja_tipo  (tipo_baja)
) ENGINE=InnoDB COMMENT='Registro de salidas de animales vivos (ventas, retiros, etc.)';

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 12: GESTIÓN DE INSUMOS
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE tbl_categoria_insumo (
    id_categoria_insumo INT AUTO_INCREMENT PRIMARY KEY,
    nombre_categoria    VARCHAR(80) NOT NULL UNIQUE,
    descripcion         VARCHAR(255) NULL,
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB COMMENT='Categorías de insumos (concentrado, forraje, medicina, etc.)';

CREATE TABLE tbl_insumo (
    id_insumo           INT AUTO_INCREMENT PRIMARY KEY,
    id_categoria_insumo INT NOT NULL,
    nombre              VARCHAR(120) NOT NULL UNIQUE,
    unidad              VARCHAR(20)  NOT NULL,
    icono               VARCHAR(60)  NULL,
    stock_actual        DECIMAL(10,2) NOT NULL DEFAULT 0,
    stock_minimo        DECIMAL(10,2) NOT NULL DEFAULT 0,
    activo              BOOLEAN   NOT NULL DEFAULT TRUE,
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_insumo_categoria FOREIGN KEY (id_categoria_insumo)
        REFERENCES tbl_categoria_insumo(id_categoria_insumo) ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_insumo_categoria (id_categoria_insumo),
    INDEX idx_insumo_activo (activo)
) ENGINE=InnoDB COMMENT='Catálogo de insumos (concentrado, heno, sal, etc.)';

-- Movimientos de inventario (compras, ventas, consumo, producción)
CREATE TABLE tbl_movimiento_insumo (
    id_mov_insumo   BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_insumo       INT    NOT NULL,
    tipo_movimiento ENUM('Compra','Venta','Producción','Consumo','Ajuste') NOT NULL,
    destino_venta   ENUM('Venta','Consumo Animal') NULL,
    cantidad        DECIMAL(10,2) NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NULL,
    total           DECIMAL(12,2) GENERATED ALWAYS AS
                    (cantidad * COALESCE(precio_unitario, 0)) STORED,
    cliente         VARCHAR(120) NULL,
    proveedor       VARCHAR(120) NULL,
    factura_url     VARCHAR(255) NULL,
    fecha_movimiento DATE      NOT NULL,
    observaciones   TEXT      NULL,
    id_usuario      INT       NULL,
    fecha_creacion  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_movins_insumo  FOREIGN KEY (id_insumo)
        REFERENCES tbl_insumo(id_insumo) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_movins_usuario FOREIGN KEY (id_usuario)
        REFERENCES tbl_usuario(id_usuario) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_movins_fecha (fecha_movimiento),
    INDEX idx_movins_tipo  (tipo_movimiento)
) ENGINE=InnoDB COMMENT='Kardex de entradas y salidas de insumos';

-- Detalle para producción de concentrado
CREATE TABLE tbl_produccion_concentrado_det (
    id_detalle     BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_mov_insumo  BIGINT NOT NULL,
    id_insumo_usado INT   NOT NULL,
    cantidad_usada DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_prodconc_mov    FOREIGN KEY (id_mov_insumo)
        REFERENCES tbl_movimiento_insumo(id_mov_insumo) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_prodconc_insumo FOREIGN KEY (id_insumo_usado)
        REFERENCES tbl_insumo(id_insumo) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB COMMENT='Detalle de insumos usados en cada lote de concentrado producido';

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 13: CONTABILIDAD / FINANZAS
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE tbl_transaccion_financiera (
    id_transaccion     BIGINT AUTO_INCREMENT PRIMARY KEY,
    categoria          ENUM('ingreso','gasto') NOT NULL,
    fecha_transaccion  DATE          NOT NULL,
    concepto           VARCHAR(120)  NOT NULL,
    descripcion        TEXT          NULL,
    monto              DECIMAL(12,2) NOT NULL CHECK (monto >= 0),
    estado             ENUM('ejecutado','pendiente') NOT NULL DEFAULT 'ejecutado',
    url_factura        VARCHAR(2083) NULL,
    id_usuario         INT           NULL,
    fecha_creacion     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_trans_usuario FOREIGN KEY (id_usuario)
        REFERENCES tbl_usuario(id_usuario) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_trans_fecha     (fecha_transaccion),
    INDEX idx_trans_categoria (categoria)
) ENGINE=InnoDB COMMENT='Registro de ingresos y gastos del establecimiento';

USE BD_Hofloc_Gestion;
SET FOREIGN_KEY_CHECKS = 0;

-- ════════════════════════════════════════════════════════════════════════════
--  PASO 1: Ampliar tbl_transaccion_financiera
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE tbl_transaccion_financiera
    ADD COLUMN tipo_origen ENUM(
                                'Manual',
                                'Compra Insumo',
                                'Venta Insumo',
                                'Venta Animal',
                                'Ingreso Leche',
                                'Gasto Sanitario',
                                'Otro'
                            ) NOT NULL DEFAULT 'Manual'
        COMMENT 'Módulo que originó la transacción'
        AFTER descripcion,

    ADD COLUMN id_mov_insumo BIGINT NULL
        COMMENT 'FK hacia movimiento de insumo si el origen es una compra/venta de insumo'
        AFTER tipo_origen,

    ADD CONSTRAINT fk_trans_mov_insumo
        FOREIGN KEY (id_mov_insumo)
        REFERENCES tbl_movimiento_insumo(id_mov_insumo)
        ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE tbl_transaccion_financiera
    ADD INDEX idx_trans_origen  (tipo_origen),
    ADD INDEX idx_trans_insumo  (id_mov_insumo);

-- ════════════════════════════════════════════════════════════════════════════
--  PASO 2: tbl_transaccion_animal (CORREGIDA)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE tbl_transaccion_animal (
    id_trans_animal  BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_transaccion   BIGINT NOT NULL COMMENT 'Asiento contable padre (cabecera)',
    id_baja          BIGINT NOT NULL COMMENT 'Baja del animal que generó el ingreso',
    precio_acordado  DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT 'Precio final pactado en la venta',
    comision_pct     DECIMAL(5,2) NOT NULL DEFAULT 0.00 COMMENT 'Comisión de intermediario en % (Obligatorio 0 para cálculo generado)',
    
    -- Corrección: Se eliminan los COALESCE para permitir que la columna sea STORED sin errores en MySQL
    comision_monto   DECIMAL(12,2) GENERATED ALWAYS AS (precio_acordado * comision_pct / 100.00) STORED,
    neto_recibido    DECIMAL(12,2) GENERATED ALWAYS AS (precio_acordado - (precio_acordado * comision_pct / 100.00)) STORED,
    
    notas            VARCHAR(255) NULL,
    fecha_creacion   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_trani_trans FOREIGN KEY (id_transaccion)
        REFERENCES tbl_transaccion_financiera(id_transaccion)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_trani_baja  FOREIGN KEY (id_baja)
        REFERENCES tbl_baja_animal(id_baja)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    INDEX idx_trani_trans (id_transaccion),
    INDEX idx_trani_baja  (id_baja)
) ENGINE=InnoDB COMMENT='Detalle contable de ingresos por venta de animales';

-- ════════════════════════════════════════════════════════════════════════════
--  PASO 3: tbl_transaccion_leche
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE tbl_transaccion_leche (
    id_trans_leche   BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_transaccion   BIGINT        NOT NULL COMMENT 'Asiento contable padre',
    fecha_inicio     DATE          NOT NULL COMMENT 'Inicio del período de producción liquidado',
    fecha_fin        DATE          NOT NULL COMMENT 'Fin del período de producción liquidado',
    total_litros     DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Litros totales del período',
    precio_litro     DECIMAL(8,4)  NOT NULL DEFAULT 0.0000 COMMENT 'Precio acordado por litro',
    descuentos       DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT 'Descuentos aplicados',
    ingreso_bruto    DECIMAL(12,2) GENERATED ALWAYS AS (total_litros * precio_litro) STORED,
    ingreso_neto     DECIMAL(12,2) GENERATED ALWAYS AS ((total_litros * precio_litro) - descuentos) STORED,
    comprador        VARCHAR(120)  NULL,
    notas            VARCHAR(255)  NULL,
    fecha_creacion   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_tranl_trans FOREIGN KEY (id_transaccion)
        REFERENCES tbl_transaccion_financiera(id_transaccion)
        ON UPDATE CASCADE ON DELETE CASCADE,

    INDEX idx_tranl_trans  (id_transaccion),
    INDEX idx_tranl_fechas (fecha_inicio, fecha_fin)
) ENGINE=InnoDB COMMENT='Liquidaciones de leche vinculadas a contabilidad';

SET FOREIGN_KEY_CHECKS = 1;

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 14: ALERTAS DEL SISTEMA
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE tbl_alerta (
    id_alerta          BIGINT AUTO_INCREMENT PRIMARY KEY,
    modulo             ENUM('Reproducción','Gestión Sanitaria','Mortalidad',
                            'Producción','Inventario','General') NOT NULL,
    id_animal          INT          NULL,
    id_origen          BIGINT       NULL,
    tipo               VARCHAR(120) NOT NULL,
    descripcion        TEXT         NULL,
    prioridad          ENUM('Urgente','Normal','Baja') NOT NULL DEFAULT 'Normal',
    fecha_programada   DATE         NOT NULL,
    estado             ENUM('Pendiente','Atendida','Cancelada') NOT NULL DEFAULT 'Pendiente',
    url_destino        VARCHAR(255) NULL,
    enviar_correo      BOOLEAN      NOT NULL DEFAULT FALSE COMMENT 'Requiere envío de email',
    correo_enviado     BOOLEAN      NOT NULL DEFAULT FALSE COMMENT 'Email ya procesado',
    notificacion_vista BOOLEAN      NOT NULL DEFAULT FALSE COMMENT 'Notificación leída en app',
    fecha_atendida     DATETIME     NULL,
    id_usuario_atiende INT          NULL,
    fecha_creacion     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_alerta_animal  FOREIGN KEY (id_animal)
        REFERENCES tbl_animal(id_animal) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_alerta_usuario FOREIGN KEY (id_usuario_atiende)
        REFERENCES tbl_usuario(id_usuario) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_alerta_estado    (estado),
    INDEX idx_alerta_prioridad (prioridad),
    INDEX idx_alerta_fecha     (fecha_programada),
    INDEX idx_alerta_modulo    (modulo)
) ENGINE=InnoDB COMMENT='Alertas automáticas del sistema';

-- ════════════════════════════════════════════════════════════════════════════
--  TABLA AUDITORÍA DE ALERTAS
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE tbl_auditoria_alerta (
    id_auditoria       BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_alerta          BIGINT       NULL,         -- NULL si la alerta fue eliminada
    modulo             VARCHAR(50)  NOT NULL,
    id_animal          INT          NULL,
    id_origen          BIGINT       NULL,
    tipo               VARCHAR(120) NOT NULL,
    descripcion        TEXT         NULL,
    prioridad          VARCHAR(20)  NOT NULL,
    fecha_programada   DATE         NOT NULL,
    estado_anterior    VARCHAR(20)  NOT NULL,
    estado_nuevo       VARCHAR(20)  NULL,
    accion_auditoria   ENUM('Creada','Modificada','Atendida','Cancelada','Eliminada')
                       NOT NULL DEFAULT 'Creada',
    fecha_auditoria    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_auditor    VARCHAR(100) NULL COMMENT 'Usuario del sistema que ejecutó la acción',
    -- [C2] FK que faltaba:
    CONSTRAINT fk_audit_alerta FOREIGN KEY (id_alerta)
        REFERENCES tbl_alerta(id_alerta) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_aud_alerta_id  (id_alerta),
    INDEX idx_aud_fecha      (fecha_auditoria),
    INDEX idx_aud_accion     (accion_auditoria)
) ENGINE=InnoDB COMMENT='Historial de cambios y eliminaciones de alertas (auditoría forense)';
-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 15: BITÁCORA DE AUDITORÍA
-- ════════════════════════════════════════════════════════════════════════════
CREATE TABLE tbl_bitacora (
    id_bitacora    BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_usuario     INT          NULL,
    accion         VARCHAR(50)  NOT NULL,    -- INSERT / UPDATE / DELETE / LOGIN
    tabla_afectada VARCHAR(80)  NOT NULL,
    id_registro    VARCHAR(40)  NULL,
    detalle        JSON         NULL,
    ip_cliente     VARCHAR(45)  NULL,
    fecha_accion   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bit_usuario FOREIGN KEY (id_usuario)
        REFERENCES tbl_usuario(id_usuario) ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_bit_fecha (fecha_accion),
    INDEX idx_bit_tabla (tabla_afectada)
) ENGINE=InnoDB COMMENT='Auditoría de todas las operaciones del sistema';



SELECT COUNT(*) AS total_tablas
FROM information_schema.tables 
WHERE table_schema = 'bd_vaquitas';

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                          FIN DEL SCRIPT v2.0                            ║
-- ╚══════════════════════════════════════════════════════════════════════════╝