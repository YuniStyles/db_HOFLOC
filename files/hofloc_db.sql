-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                  HOFLOC.SA — EL ARCHIVO AGRARIO                          ║
-- ║          BASE DE DATOS NORMALIZADA (3FN) - MySQL 8.0+                    ║
-- ║                                                                          ║
-- ║  Diseño derivado de los formularios de la vista de administrador:        ║
-- ║   - Registro Ganadero (Vaca / Toro / Ternero)                            ║
-- ║   - Mangas / Lotes                                                       ║
-- ║   - Pesaje                                                               ║
-- ║   - Producción (Ordeño)                                                  ║
-- ║   - Gestión Sanitaria (Vacunación / Tratamiento / Mastitis)              ║
-- ║   - Reproducción (Inseminación Artificial / Monta Natural / Palpación)   ║
-- ║   - Mortalidad                                                           ║
-- ║   - Gestión de Insumos (Compra / Venta / Producción / Consumo)           ║
-- ║   - Colaboradores / Usuarios / Roles                                     ║
-- ║   - Alertas                                                              ║
-- ║   - Reportes                                                             ║
-- ║                                                                          ║
-- ║  Estrategia de herencia por tipo de animal:                              ║
-- ║   Tabla padre `tbl_animal` (datos comunes) +                             ║
-- ║   Tablas hijas `tbl_vaca`, `tbl_toro`, `tbl_ternero` (datos específicos) ║
-- ║   Relación 1:1 mediante id_animal como FK y PK simultáneamente.          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

DROP DATABASE IF EXISTS hofloc_db;
CREATE DATABASE hofloc_db
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;
USE hofloc_db;

SET FOREIGN_KEY_CHECKS = 0;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 1: SEGURIDAD - USUARIOS, ROLES Y COLABORADORES                   ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ── Tabla de roles (SuperAdmin, Administrador, Supervisor, Empleado, Veterinario)
CREATE TABLE tbl_rol (
    id_rol          INT AUTO_INCREMENT PRIMARY KEY,
    nombre_rol      VARCHAR(50) NOT NULL UNIQUE,
    descripcion     VARCHAR(255) NULL,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ── Tabla principal de usuarios del sistema (acceso)
CREATE TABLE tbl_usuario (
    id_usuario      INT AUTO_INCREMENT PRIMARY KEY,
    usuario         VARCHAR(50) NOT NULL UNIQUE,
    email           VARCHAR(120) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    nombre_completo VARCHAR(120) NOT NULL,
    telefono        VARCHAR(25) NULL,
    id_rol          INT NOT NULL,
    estado          ENUM('activo','inactivo','bloqueado') NOT NULL DEFAULT 'activo',
    ultimo_login    DATETIME NULL,
    fecha_creacion  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modif     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_usuario_rol FOREIGN KEY (id_rol) REFERENCES tbl_rol(id_rol)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_usuario_estado (estado),
    INDEX idx_usuario_email  (email)
) ENGINE=InnoDB;

-- ── Tabla de colaboradores (empleados de campo, veterinarios, etc.)
CREATE TABLE tbl_colaborador (
    id_colaborador  INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario      INT NULL,                    -- NULL si no tiene acceso al sistema
    nombre          VARCHAR(120) NOT NULL,
    telefono        VARCHAR(25) NULL,
    correo          VARCHAR(120) NULL,
    id_rol          INT NOT NULL,
    estado          ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',
    notas           TEXT NULL,
    fecha_ingreso   DATE NOT NULL DEFAULT (CURRENT_DATE),
    fecha_creacion  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_colab_usuario FOREIGN KEY (id_usuario) REFERENCES tbl_usuario(id_usuario)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_colab_rol     FOREIGN KEY (id_rol) REFERENCES tbl_rol(id_rol)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_colab_estado (estado)
) ENGINE=InnoDB;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 2: CATÁLOGOS BASE                                                ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ── Razas (Angus, Brahman, Holstein, Jersey, Pardo Suizo, etc.)
CREATE TABLE tbl_raza (
    id_raza         INT AUTO_INCREMENT PRIMARY KEY,
    nombre_raza     VARCHAR(60) NOT NULL UNIQUE,
    proposito       ENUM('Carne','Leche','Doble Propósito') NOT NULL DEFAULT 'Doble Propósito',
    descripcion     VARCHAR(255) NULL,
    activo          BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

-- ── Procedencia del animal (Nacido en finca / Comprado / Donado)
CREATE TABLE tbl_procedencia (
    id_procedencia  INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(60) NOT NULL UNIQUE,
    descripcion     VARCHAR(255) NULL
) ENGINE=InnoDB;

-- ── Mangas (lotes/corrales del establecimiento)
CREATE TABLE tbl_manga (
    id_manga        INT AUTO_INCREMENT PRIMARY KEY,
    numero_manga    INT NOT NULL UNIQUE,         -- número visible (#00, #01, ...)
    nombre          VARCHAR(60) NOT NULL,        -- "Lechería", "Pre-Parto", etc.
    funcion         ENUM('Ordeño','Cría','Reproducción','Preparto','Novillas',
                         'Machos Levante','Ceba','Lactancia','Sementales',
                         'Toretes Ceba','Terneros','Corral','Otro')
                    NOT NULL DEFAULT 'Otro',
    capacidad_max   INT NOT NULL DEFAULT 0,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_manga_funcion (funcion)
) ENGINE=InnoDB;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 3: ANIMALES — JERARQUÍA (PADRE + HIJAS POR TIPO)                 ║
-- ║                                                                          ║
-- ║  Patrón: "Class Table Inheritance"                                       ║
-- ║   tbl_animal     → datos comunes (arete, raza, manga, fechas, estado)    ║
-- ║   tbl_vaca       → atributos exclusivos de hembras adultas               ║
-- ║   tbl_toro       → atributos exclusivos de machos adultos                ║
-- ║   tbl_ternero    → atributos exclusivos de crías (machos y hembras)      ║
-- ║                                                                          ║
-- ║  Reglas:                                                                 ║
-- ║   • Un registro de tbl_animal SOLO puede tener fila en UNA tabla hija    ║
-- ║     (trigger valida y enum 'tipo_animal' lo refuerza)                    ║
-- ║   • El id_animal es a la vez PK de la hija y FK al padre (1:1)           ║
-- ║   • Al promover un ternero a vaca/toro: se mantiene el id_animal,        ║
-- ║     se cambia el campo 'tipo_animal' y se mueve la fila a la nueva       ║
-- ║     tabla hija (procedimiento sp_promover_ternero)                       ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ── Tabla PADRE: datos comunes a todo animal ──────────────────────────────────
CREATE TABLE tbl_animal (
    id_animal          INT AUTO_INCREMENT PRIMARY KEY,
    arete              VARCHAR(20) NOT NULL UNIQUE,         -- ID único físico
    trazabilidad       VARCHAR(20) NULL,                    -- Código MIDA / trazab.
    tipo_animal        ENUM('Vaca','Toro','Ternero') NOT NULL,
    sexo               ENUM('Macho','Hembra') NOT NULL,
    id_raza            INT NOT NULL,
    id_manga_actual    INT NULL,                            -- manga donde está hoy
    id_procedencia     INT NULL,
    fecha_nacimiento   DATE NOT NULL,
    fecha_ingreso      DATE NOT NULL DEFAULT (CURRENT_DATE),
    peso_actual_kg     DECIMAL(7,2) NULL,                   -- último peso registrado
    estado_general     ENUM('Saludable','Tratamiento','Desparacitación',
                            'Enfermo','Cuarentena','Vendido','Fallecido')
                       NOT NULL DEFAULT 'Saludable',
    foto_url           VARCHAR(255) NULL,
    observaciones      TEXT NULL,
    fecha_creacion     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modif        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_animal_raza        FOREIGN KEY (id_raza)         REFERENCES tbl_raza(id_raza),
    CONSTRAINT fk_animal_manga       FOREIGN KEY (id_manga_actual) REFERENCES tbl_manga(id_manga)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_animal_procedencia FOREIGN KEY (id_procedencia)  REFERENCES tbl_procedencia(id_procedencia),
    INDEX idx_animal_tipo  (tipo_animal),
    INDEX idx_animal_arete (arete),
    INDEX idx_animal_estado(estado_general)
) ENGINE=InnoDB;

-- ── Tabla HIJA: VACA (hembras en producción/reproducción) ────────────────────
CREATE TABLE tbl_vaca (
    id_animal          INT PRIMARY KEY,                     -- mismo id que tbl_animal
    estado_productivo  ENUM('Producción','Preñada','Levante','Seca','Vacía')
                       NOT NULL DEFAULT 'Vacía',
    estado_lactancia   ENUM('Lactando','Seca','N/A') NOT NULL DEFAULT 'N/A',
    numero_partos      INT NOT NULL DEFAULT 0,
    fecha_ultimo_parto DATE NULL,
    fecha_ultimo_celo  DATE NULL,
    proposito          ENUM('Leche','Doble Propósito') NOT NULL DEFAULT 'Leche',
    produccion_promedio_lt DECIMAL(6,2) NULL,                -- L/día promedio histórico
    CONSTRAINT fk_vaca_animal FOREIGN KEY (id_animal) REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Tabla HIJA: TORO (machos reproductores / ceba) ───────────────────────────
CREATE TABLE tbl_toro (
    id_animal          INT PRIMARY KEY,
    tipo_uso           ENUM('Semental','Ceba','Levante') NOT NULL DEFAULT 'Semental',
    num_montas_total   INT NOT NULL DEFAULT 0,
    activo_reproduccion BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_inicio_reprod DATE NULL,
    perimetro_escrotal_cm DECIMAL(5,2) NULL,
    libido_evaluacion   ENUM('Alta','Media','Baja','Sin evaluar') NOT NULL DEFAULT 'Sin evaluar',
    CONSTRAINT fk_toro_animal FOREIGN KEY (id_animal) REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Tabla HIJA: TERNERO (crías < 12 meses, m o h) ────────────────────────────
CREATE TABLE tbl_ternero (
    id_animal             INT PRIMARY KEY,
    numero_interno        VARCHAR(20) NULL,                 -- en lugar de arete oficial
    corral                VARCHAR(60) NULL,
    id_madre              INT NULL,                          -- referencia a vaca madre
    id_padre              INT NULL,                          -- referencia a toro padre
    peso_nacimiento_kg    DECIMAL(6,2) NULL,
    estado_lactancia      ENUM('Lactante','Destetado','Pre-destete') NOT NULL DEFAULT 'Lactante',
    fecha_destete         DATE NULL,
    esquema_vacunas       VARCHAR(120) NULL DEFAULT 'Esquema inicial',
    CONSTRAINT fk_tern_animal FOREIGN KEY (id_animal) REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_tern_madre  FOREIGN KEY (id_madre)  REFERENCES tbl_vaca(id_animal)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_tern_padre  FOREIGN KEY (id_padre)  REFERENCES tbl_toro(id_animal)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 4: MOVIMIENTOS ENTRE MANGAS (historial)                          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

CREATE TABLE tbl_movimiento_manga (
    id_movimiento     BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal         INT NOT NULL,
    id_manga_origen   INT NULL,
    id_manga_destino  INT NOT NULL,
    tipo_movimiento   ENUM('Unitario','Masivo') NOT NULL DEFAULT 'Unitario',
    motivo            VARCHAR(255) NULL,
    fecha_movimiento  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario        INT NULL,
    CONSTRAINT fk_mov_animal  FOREIGN KEY (id_animal)        REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_mov_origen  FOREIGN KEY (id_manga_origen)  REFERENCES tbl_manga(id_manga),
    CONSTRAINT fk_mov_destino FOREIGN KEY (id_manga_destino) REFERENCES tbl_manga(id_manga),
    CONSTRAINT fk_mov_usuario FOREIGN KEY (id_usuario)       REFERENCES tbl_usuario(id_usuario),
    INDEX idx_mov_fecha (fecha_movimiento)
) ENGINE=InnoDB;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 5: PESAJE                                                        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

CREATE TABLE tbl_pesaje (
    id_pesaje         BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal         INT NOT NULL,
    fecha_pesaje      DATE NOT NULL,
    hora_pesaje       TIME NULL,
    peso_kg           DECIMAL(7,2) NOT NULL CHECK (peso_kg > 0),
    tipo_alimentacion ENUM('Mixto','Estabulado','Pastoreo') NOT NULL DEFAULT 'Pastoreo',
    observaciones     TEXT NULL,
    id_usuario        INT NULL,
    fecha_creacion    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pesaje_animal  FOREIGN KEY (id_animal)  REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_pesaje_usuario FOREIGN KEY (id_usuario) REFERENCES tbl_usuario(id_usuario),
    INDEX idx_pesaje_fecha (fecha_pesaje),
    INDEX idx_pesaje_animal_fecha (id_animal, fecha_pesaje)
) ENGINE=InnoDB;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 6: PRODUCCIÓN DE LECHE (ORDEÑO)                                  ║
-- ║   Solo aplica a registros que existan en tbl_vaca                        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

CREATE TABLE tbl_produccion_leche (
    id_produccion       BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal           INT NOT NULL,                       -- debe existir en tbl_vaca
    fecha_registro      DATE NOT NULL,
    metodo_registro     ENUM('Diario','Semanal') NOT NULL DEFAULT 'Diario',
    leche_manana_lt     DECIMAL(6,2) NULL DEFAULT 0,
    leche_tarde_lt      DECIMAL(6,2) NULL DEFAULT 0,
    concentrado_manana_kg DECIMAL(6,2) NULL DEFAULT 0,
    concentrado_tarde_kg  DECIMAL(6,2) NULL DEFAULT 0,
    total_leche_lt      DECIMAL(7,2) GENERATED ALWAYS AS
                        (COALESCE(leche_manana_lt,0) + COALESCE(leche_tarde_lt,0)) STORED,
    observaciones       TEXT NULL,
    id_usuario          INT NULL,
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_prod_vaca    FOREIGN KEY (id_animal)  REFERENCES tbl_vaca(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_prod_usuario FOREIGN KEY (id_usuario) REFERENCES tbl_usuario(id_usuario),
    UNIQUE KEY uq_prod_vaca_fecha (id_animal, fecha_registro),
    INDEX idx_prod_fecha (fecha_registro)
) ENGINE=InnoDB;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 7: GESTIÓN SANITARIA                                             ║
-- ║   Categorías: Vacunación, Tratamiento, Mastitis, Desparasitación         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ── Catálogo de vacunas y medicamentos
CREATE TABLE tbl_producto_sanitario (
    id_producto      INT AUTO_INCREMENT PRIMARY KEY,
    nombre           VARCHAR(120) NOT NULL,
    tipo             ENUM('Vacuna','Antibiótico','Antiparasitario','Vitamina',
                          'Hormonal','Otro') NOT NULL,
    unidad           VARCHAR(20) NULL,                      -- ml, mg, dosis
    laboratorio      VARCHAR(120) NULL,
    activo           BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE KEY uq_prod_san (nombre, tipo)
) ENGINE=InnoDB;

-- ── Registro maestro sanitario (cabecera del evento)
CREATE TABLE tbl_registro_sanitario (
    id_registro_san   BIGINT AUTO_INCREMENT PRIMARY KEY,
    tipo_aplicacion   ENUM('Individual','Masivo') NOT NULL,
    categoria         ENUM('Vacunación','Tratamiento','Mastitis','Desparasitación') NOT NULL,
    sub_tipo          VARCHAR(80) NULL,                     -- ej: "Antibiótico", "Hormonal"
    proposito         VARCHAR(120) NULL,                    -- ej: "Curativo", "Preventivo"
    id_producto       INT NULL,
    dosis             VARCHAR(60) NULL,
    fecha_aplicacion  DATE NOT NULL,
    hora_aplicacion   TIME NULL,
    intervalo_dias    INT NULL,                             -- para cronogramas
    notas             TEXT NULL,
    id_veterinario    INT NULL,                             -- id_colaborador
    id_usuario        INT NULL,                             -- quien registró
    fecha_creacion    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_san_producto FOREIGN KEY (id_producto)    REFERENCES tbl_producto_sanitario(id_producto),
    CONSTRAINT fk_san_vet      FOREIGN KEY (id_veterinario) REFERENCES tbl_colaborador(id_colaborador),
    CONSTRAINT fk_san_usuario  FOREIGN KEY (id_usuario)     REFERENCES tbl_usuario(id_usuario),
    INDEX idx_san_fecha (fecha_aplicacion),
    INDEX idx_san_categoria (categoria)
) ENGINE=InnoDB;

-- ── Detalle: animales aplicados a cada registro (1:N)
CREATE TABLE tbl_registro_sanitario_animal (
    id_detalle        BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_registro_san   BIGINT NOT NULL,
    id_animal         INT NOT NULL,
    observacion       VARCHAR(255) NULL,
    CONSTRAINT fk_rsa_registro FOREIGN KEY (id_registro_san) REFERENCES tbl_registro_sanitario(id_registro_san)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_rsa_animal   FOREIGN KEY (id_animal)       REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    UNIQUE KEY uq_rsa (id_registro_san, id_animal)
) ENGINE=InnoDB;

-- ── Detalle especial para mastitis: diagnóstico por cuarto mamario (solo vacas)
CREATE TABLE tbl_mastitis_cuartos (
    id_mastitis       BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_registro_san   BIGINT NOT NULL,
    id_animal         INT NOT NULL,                          -- debe ser vaca
    cuarto_ad         ENUM('Sano','Subclínico','Clínico','Crónico','No evaluado') NOT NULL DEFAULT 'No evaluado',
    cuarto_pd         ENUM('Sano','Subclínico','Clínico','Crónico','No evaluado') NOT NULL DEFAULT 'No evaluado',
    cuarto_ai         ENUM('Sano','Subclínico','Clínico','Crónico','No evaluado') NOT NULL DEFAULT 'No evaluado',
    cuarto_pi         ENUM('Sano','Subclínico','Clínico','Crónico','No evaluado') NOT NULL DEFAULT 'No evaluado',
    cmt_resultado     VARCHAR(60) NULL,                      -- ej: California Mastitis Test
    CONSTRAINT fk_mast_registro FOREIGN KEY (id_registro_san) REFERENCES tbl_registro_sanitario(id_registro_san)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_mast_vaca     FOREIGN KEY (id_animal)       REFERENCES tbl_vaca(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 8: REPRODUCCIÓN                                                  ║
-- ║   Eventos: Inseminación Artificial, Monta Natural, Palpación, Parto      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

CREATE TABLE tbl_evento_reproductivo (
    id_evento_rep     BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_vaca           INT NOT NULL,
    tipo_evento       ENUM('Inseminación Artificial','Monta Natural','Palpación',
                           'Celo','Parto','Aborto','Secado') NOT NULL,
    fecha_evento      DATE NOT NULL,
    hora_evento       TIME NULL,
    -- IA
    numero_pajilla    VARCHAR(40) NULL,
    raza_semen        VARCHAR(60) NULL,
    proveedor_semen   VARCHAR(120) NULL,
    -- Monta Natural
    id_toro           INT NULL,
    -- Palpación
    fase_palpacion    ENUM('Fase 1','Fase 2') NULL,
    resultado_palp    ENUM('Preñada','Vacía','Preñez provisional','Preñez confirmada',
                           'Sin evaluar') NULL,
    -- Resultados generales
    estado_resultado  ENUM('Programado','Realizado','Cancelado') NOT NULL DEFAULT 'Realizado',
    fecha_estimada_parto DATE NULL,                          -- calculada: +283 días si preñada
    observaciones     TEXT NULL,
    id_veterinario    INT NULL,
    id_usuario        INT NULL,
    fecha_creacion    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rep_vaca FOREIGN KEY (id_vaca) REFERENCES tbl_vaca(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_rep_toro FOREIGN KEY (id_toro) REFERENCES tbl_toro(id_animal)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_rep_vet  FOREIGN KEY (id_veterinario) REFERENCES tbl_colaborador(id_colaborador),
    CONSTRAINT fk_rep_usuario FOREIGN KEY (id_usuario)  REFERENCES tbl_usuario(id_usuario),
    INDEX idx_rep_fecha (fecha_evento),
    INDEX idx_rep_tipo  (tipo_evento)
) ENGINE=InnoDB;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 9: MORTALIDAD                                                    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

CREATE TABLE tbl_mortalidad (
    id_mortalidad     BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_animal         INT NOT NULL UNIQUE,                   -- un animal muere 1 vez
    causa             ENUM('Respiratoria','Diarrea','Digestivos','Reproductiva',
                           'Accidente','Parásitos','Vejez','Otro') NOT NULL,
    fecha_muerte      DATE NOT NULL,
    observacion       TEXT NULL,
    id_usuario        INT NULL,
    fecha_creacion    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_mort_animal  FOREIGN KEY (id_animal)  REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_mort_usuario FOREIGN KEY (id_usuario) REFERENCES tbl_usuario(id_usuario),
    INDEX idx_mort_fecha (fecha_muerte),
    INDEX idx_mort_causa (causa)
) ENGINE=InnoDB;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 10: GESTIÓN DE INSUMOS                                           ║
-- ║   Compra / Venta / Producción / Consumo Animal                           ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

CREATE TABLE tbl_insumo (
    id_insumo         INT AUTO_INCREMENT PRIMARY KEY,
    nombre            VARCHAR(120) NOT NULL UNIQUE,
    unidad            VARCHAR(20) NOT NULL,                  -- sacos, kg, litros, pacas
    icono             VARCHAR(60) NULL,
    stock_actual      DECIMAL(10,2) NOT NULL DEFAULT 0,
    stock_minimo      DECIMAL(10,2) NOT NULL DEFAULT 0,
    activo            BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_insumo_activo (activo)
) ENGINE=InnoDB;

-- ── Movimientos de inventario (compras, ventas, producción, consumo)
CREATE TABLE tbl_movimiento_insumo (
    id_mov_insumo     BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_insumo         INT NOT NULL,
    tipo_movimiento   ENUM('Compra','Venta','Producción','Consumo','Ajuste') NOT NULL,
    destino_venta     ENUM('Venta','Consumo Animal') NULL,
    cantidad          DECIMAL(10,2) NOT NULL CHECK (cantidad > 0),
    precio_unitario   DECIMAL(10,2) NULL,
    total             DECIMAL(12,2) GENERATED ALWAYS AS
                      (cantidad * COALESCE(precio_unitario, 0)) STORED,
    cliente           VARCHAR(120) NULL,                     -- solo venta
    proveedor         VARCHAR(120) NULL,                     -- solo compra
    factura_url       VARCHAR(255) NULL,
    fecha_movimiento  DATE NOT NULL,
    observaciones     TEXT NULL,
    id_usuario        INT NULL,
    fecha_creacion    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_movins_insumo  FOREIGN KEY (id_insumo)  REFERENCES tbl_insumo(id_insumo),
    CONSTRAINT fk_movins_usuario FOREIGN KEY (id_usuario) REFERENCES tbl_usuario(id_usuario),
    INDEX idx_movins_fecha (fecha_movimiento),
    INDEX idx_movins_tipo  (tipo_movimiento)
) ENGINE=InnoDB;

-- ── Detalle para producción de concentrado (qué insumos se usaron)
CREATE TABLE tbl_produccion_concentrado_det (
    id_detalle        BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_mov_insumo     BIGINT NOT NULL,                       -- el movimiento de producción
    id_insumo_usado   INT NOT NULL,
    cantidad_usada    DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_prodconc_mov    FOREIGN KEY (id_mov_insumo)   REFERENCES tbl_movimiento_insumo(id_mov_insumo)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_prodconc_insumo FOREIGN KEY (id_insumo_usado) REFERENCES tbl_insumo(id_insumo)
) ENGINE=InnoDB;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 11: ALERTAS DEL SISTEMA                                          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

CREATE TABLE tbl_alerta (
    id_alerta         BIGINT AUTO_INCREMENT PRIMARY KEY,
    modulo            ENUM('Reproducción','Gestión Sanitaria','Mortalidad',
                           'Producción','Inventario','General') NOT NULL,
    id_animal         INT NULL,
    id_origen         BIGINT NULL,                           -- id genérico del evento origen
    tipo              VARCHAR(120) NOT NULL,                 -- "Palpación Fase 1", "Vacunación"
    descripcion       TEXT NULL,
    prioridad         ENUM('Urgente','Normal','Baja') NOT NULL DEFAULT 'Normal',
    fecha_programada  DATE NOT NULL,
    estado            ENUM('Pendiente','Atendida','Cancelada') NOT NULL DEFAULT 'Pendiente',
    url_destino       VARCHAR(255) NULL,
    fecha_atendida    DATETIME NULL,
    id_usuario_atiende INT NULL,
    fecha_creacion    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_alerta_animal  FOREIGN KEY (id_animal) REFERENCES tbl_animal(id_animal)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_alerta_usuario FOREIGN KEY (id_usuario_atiende) REFERENCES tbl_usuario(id_usuario),
    INDEX idx_alerta_estado    (estado),
    INDEX idx_alerta_prioridad (prioridad),
    INDEX idx_alerta_fecha     (fecha_programada)
) ENGINE=InnoDB;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 12: BITÁCORA DE AUDITORÍA                                        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

CREATE TABLE tbl_bitacora (
    id_bitacora       BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_usuario        INT NULL,
    accion            VARCHAR(50) NOT NULL,                  -- INSERT/UPDATE/DELETE/LOGIN
    tabla_afectada    VARCHAR(80) NOT NULL,
    id_registro       VARCHAR(40) NULL,
    detalle           JSON NULL,
    ip_cliente        VARCHAR(45) NULL,
    fecha_accion      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bit_usuario FOREIGN KEY (id_usuario) REFERENCES tbl_usuario(id_usuario),
    INDEX idx_bit_fecha (fecha_accion),
    INDEX idx_bit_tabla (tabla_afectada)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 13: TRIGGERS - INTEGRIDAD DE LA HERENCIA                         ║
-- ║                                                                          ║
-- ║  Estos triggers garantizan que el campo tipo_animal en tbl_animal        ║
-- ║  coincida con la tabla hija donde realmente existe el registro,          ║
-- ║  y que NO se pueda insertar el mismo id_animal en dos tablas hijas.      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

DELIMITER $$

-- Validar que al crear una vaca, el animal padre tenga tipo_animal='Vaca'
CREATE TRIGGER trg_vaca_check_tipo
BEFORE INSERT ON tbl_vaca
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    SELECT tipo_animal INTO v_tipo FROM tbl_animal WHERE id_animal = NEW.id_animal;
    IF v_tipo IS NULL OR v_tipo <> 'Vaca' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El animal padre debe tener tipo_animal = "Vaca"';
    END IF;
END$$

CREATE TRIGGER trg_toro_check_tipo
BEFORE INSERT ON tbl_toro
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    SELECT tipo_animal INTO v_tipo FROM tbl_animal WHERE id_animal = NEW.id_animal;
    IF v_tipo IS NULL OR v_tipo <> 'Toro' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El animal padre debe tener tipo_animal = "Toro"';
    END IF;
END$$

CREATE TRIGGER trg_ternero_check_tipo
BEFORE INSERT ON tbl_ternero
FOR EACH ROW
BEGIN
    DECLARE v_tipo VARCHAR(20);
    SELECT tipo_animal INTO v_tipo FROM tbl_animal WHERE id_animal = NEW.id_animal;
    IF v_tipo IS NULL OR v_tipo <> 'Ternero' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El animal padre debe tener tipo_animal = "Ternero"';
    END IF;
END$$

-- Al marcar un animal como Fallecido, actualizar tabla mortalidad coherente
CREATE TRIGGER trg_mortalidad_update_animal
AFTER INSERT ON tbl_mortalidad
FOR EACH ROW
BEGIN
    UPDATE tbl_animal
       SET estado_general = 'Fallecido'
     WHERE id_animal = NEW.id_animal;
END$$

-- Actualizar peso_actual_kg al registrar nuevo pesaje
CREATE TRIGGER trg_pesaje_update_animal
AFTER INSERT ON tbl_pesaje
FOR EACH ROW
BEGIN
    UPDATE tbl_animal
       SET peso_actual_kg = NEW.peso_kg
     WHERE id_animal = NEW.id_animal;
END$$

DELIMITER ;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 14: STORED PROCEDURE - INSERTAR ANIMAL SEGÚN SU TIPO             ║
-- ║                                                                          ║
-- ║  Este SP es lo que el formulario del admin debe llamar.                  ║
-- ║  Recibe el tipo y, en una sola transacción, inserta en tbl_animal +      ║
-- ║  en la tabla hija correspondiente (tbl_vaca | tbl_toro | tbl_ternero).   ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

DELIMITER $$

CREATE PROCEDURE sp_registrar_animal(
    IN  p_tipo_animal     VARCHAR(20),       -- 'Vaca' | 'Toro' | 'Ternero'
    IN  p_arete           VARCHAR(20),
    IN  p_trazabilidad    VARCHAR(20),
    IN  p_sexo            VARCHAR(10),
    IN  p_id_raza         INT,
    IN  p_id_manga        INT,
    IN  p_id_procedencia  INT,
    IN  p_fecha_nacimiento DATE,
    IN  p_peso_kg         DECIMAL(7,2),
    IN  p_proposito       VARCHAR(40),       -- vaca/toro
    IN  p_id_madre        INT,               -- ternero
    IN  p_id_padre        INT,               -- ternero
    IN  p_id_usuario      INT,
    OUT p_id_animal_out   INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Insertar en tabla padre
    INSERT INTO tbl_animal (
        arete, trazabilidad, tipo_animal, sexo, id_raza,
        id_manga_actual, id_procedencia, fecha_nacimiento, peso_actual_kg
    ) VALUES (
        p_arete, p_trazabilidad, p_tipo_animal, p_sexo, p_id_raza,
        p_id_manga, p_id_procedencia, p_fecha_nacimiento, p_peso_kg
    );

    SET p_id_animal_out = LAST_INSERT_ID();

    -- 2. Insertar en tabla hija según tipo
    IF p_tipo_animal = 'Vaca' THEN
        INSERT INTO tbl_vaca (id_animal, proposito)
        VALUES (p_id_animal_out, COALESCE(p_proposito, 'Leche'));

    ELSEIF p_tipo_animal = 'Toro' THEN
        INSERT INTO tbl_toro (id_animal, tipo_uso)
        VALUES (p_id_animal_out, COALESCE(p_proposito, 'Semental'));

    ELSEIF p_tipo_animal = 'Ternero' THEN
        INSERT INTO tbl_ternero (id_animal, id_madre, id_padre, peso_nacimiento_kg)
        VALUES (p_id_animal_out, p_id_madre, p_id_padre, p_peso_kg);
    ELSE
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tipo de animal no válido (use Vaca/Toro/Ternero)';
    END IF;

    -- 3. Auditoría
    INSERT INTO tbl_bitacora (id_usuario, accion, tabla_afectada, id_registro, detalle)
    VALUES (p_id_usuario, 'INSERT', 'tbl_animal', p_id_animal_out,
            JSON_OBJECT('tipo', p_tipo_animal, 'arete', p_arete));

    COMMIT;
END$$

-- ── SP: Promover Ternero a Vaca/Toro al cumplir edad
CREATE PROCEDURE sp_promover_ternero(
    IN p_id_animal    INT,
    IN p_nuevo_tipo   VARCHAR(20),    -- 'Vaca' o 'Toro'
    IN p_proposito    VARCHAR(40),
    IN p_id_usuario   INT
)
BEGIN
    DECLARE v_sexo VARCHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Validar sexo coincide
    SELECT sexo INTO v_sexo FROM tbl_animal WHERE id_animal = p_id_animal;
    IF (p_nuevo_tipo = 'Vaca' AND v_sexo <> 'Hembra')
       OR (p_nuevo_tipo = 'Toro' AND v_sexo <> 'Macho') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El sexo del animal no permite la promoción solicitada';
    END IF;

    -- 1. Quitar de tbl_ternero
    DELETE FROM tbl_ternero WHERE id_animal = p_id_animal;

    -- 2. Cambiar tipo en tbl_animal
    UPDATE tbl_animal SET tipo_animal = p_nuevo_tipo WHERE id_animal = p_id_animal;

    -- 3. Insertar en la tabla destino
    IF p_nuevo_tipo = 'Vaca' THEN
        INSERT INTO tbl_vaca (id_animal, proposito)
        VALUES (p_id_animal, COALESCE(p_proposito, 'Leche'));
    ELSE
        INSERT INTO tbl_toro (id_animal, tipo_uso)
        VALUES (p_id_animal, COALESCE(p_proposito, 'Semental'));
    END IF;

    INSERT INTO tbl_bitacora (id_usuario, accion, tabla_afectada, id_registro, detalle)
    VALUES (p_id_usuario, 'PROMOTE', 'tbl_animal', p_id_animal,
            JSON_OBJECT('nuevo_tipo', p_nuevo_tipo));

    COMMIT;
END$$

DELIMITER ;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 15: VISTAS ÚTILES                                                ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Vista unificada de animales con su tipo y atributos específicos
CREATE OR REPLACE VIEW vw_animal_completo AS
SELECT
    a.id_animal, a.arete, a.trazabilidad, a.tipo_animal, a.sexo,
    r.nombre_raza, m.nombre AS manga, m.numero_manga,
    a.fecha_nacimiento,
    TIMESTAMPDIFF(MONTH, a.fecha_nacimiento, CURDATE()) AS edad_meses,
    a.peso_actual_kg, a.estado_general,
    v.estado_productivo, v.numero_partos, v.proposito AS proposito_vaca,
    t.tipo_uso, t.activo_reproduccion,
    te.numero_interno, te.estado_lactancia AS estado_lact_ternero
FROM tbl_animal a
LEFT JOIN tbl_raza   r  ON a.id_raza = r.id_raza
LEFT JOIN tbl_manga  m  ON a.id_manga_actual = m.id_manga
LEFT JOIN tbl_vaca   v  ON a.id_animal = v.id_animal
LEFT JOIN tbl_toro   t  ON a.id_animal = t.id_animal
LEFT JOIN tbl_ternero te ON a.id_animal = te.id_animal;

-- Vista de inventario actual de mangas
CREATE OR REPLACE VIEW vw_inventario_mangas AS
SELECT m.id_manga, m.numero_manga, m.nombre, m.funcion,
       COUNT(a.id_animal) AS cantidad_actual,
       m.capacidad_max
FROM tbl_manga m
LEFT JOIN tbl_animal a ON a.id_manga_actual = m.id_manga
                       AND a.estado_general NOT IN ('Fallecido','Vendido')
GROUP BY m.id_manga, m.numero_manga, m.nombre, m.funcion, m.capacidad_max;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BLOQUE 16: DATOS INICIALES (SEED)                                       ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Roles
INSERT INTO tbl_rol (nombre_rol, descripcion) VALUES
('SuperAdmin',    'Acceso total al sistema'),
('Administrador', 'Gestión contable y reportes'),
('Supervisor',    'Supervisión de operaciones'),
('Empleado',      'Operaciones de campo'),
('Veterinario',   'Atención sanitaria y reproductiva');

-- Razas
INSERT INTO tbl_raza (nombre_raza, proposito) VALUES
('Holstein',     'Leche'),
('Jersey',       'Leche'),
('Pardo Suizo',  'Doble Propósito'),
('Brahman',      'Carne'),
('Angus',        'Carne'),
('Charolais',    'Carne'),
('Gyr',          'Leche'),
('Girolando',    'Doble Propósito');

-- Procedencias
INSERT INTO tbl_procedencia (nombre, descripcion) VALUES
('Nacido en finca', 'Cría propia'),
('Comprado',        'Adquirido a un tercero'),
('Donado',          'Recibido en donación');

-- Mangas (basadas en los datos reales del sistema)
INSERT INTO tbl_manga (numero_manga, nombre, funcion, capacidad_max) VALUES
(0,  'Lechería',     'Ordeño',         80),
(1,  'Pre-Parto',    'Preparto',       40),
(2,  'Cría',         'Cría',           60),
(3,  'Los Mangos',   'Lactancia',      40),
(4,  'Corral',       'Corral',         50),
(5,  'Sementales',   'Sementales',     15),
(6,  'Toretes Ceba', 'Toretes Ceba',   30),
(7,  'Novillas H',   'Novillas',       25),
(8,  'Terneros M',   'Terneros',       20),
(9,  'Reproducción', 'Reproducción',   30);

-- Insumos
INSERT INTO tbl_insumo (nombre, unidad, stock_actual, stock_minimo) VALUES
('Concentrado',    'sacos',  80, 20),
('Heno Procesado', 'pacas', 120, 30),
('Sal Mineral',    'kg',    200, 50),
('Melaza',         'litros', 50, 15);

-- Usuario administrador inicial (la contraseña real debe hashearse con bcrypt en backend)
INSERT INTO tbl_usuario (usuario, email, password_hash, nombre_completo, id_rol, estado)
VALUES ('Horacio', 'horacio.flores@hofloc.com',
        '$2y$10$REEMPLAZAR_POR_HASH_BCRYPT_REAL', 'Horacio Flores', 1, 'activo');

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                              FIN DEL SCRIPT                              ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
