
-- Iniciar con las Base de datos
USE BD_vaquitas;

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 16: TRIGGERS
-- ════════════════════════════════════════════════════════════════════════════

DELIMITER $$

-- ── T1: Marcar animal como Fallecido al registrar muerte ─────────────────────
CREATE TRIGGER trg_mort_estado_animal
AFTER INSERT ON tbl_mortalidad
FOR EACH ROW
BEGIN
    UPDATE tbl_animal
       SET estado_animal = 'Fallecido'
     WHERE id_animal = NEW.id_animal;

    INSERT INTO tbl_animal_auditoria
        (id_animal, accion, estado_anterior, estado_nuevo, motivo, fecha_evento)
    VALUES
        (NEW.id_animal, 'Muerte', 'Activo', 'Fallecido',
         'Registro automático por mortalidad', NEW.fecha_muerte);
END$$

-- ── T2: Marcar animal como Vendido al registrar baja ─────────────────────────
CREATE TRIGGER trg_baja_estado_animal
AFTER INSERT ON tbl_baja_animal
FOR EACH ROW
BEGIN
    UPDATE tbl_animal
       SET estado_animal = 'Vendido'
     WHERE id_animal = NEW.id_animal;

    INSERT INTO tbl_animal_auditoria
        (id_animal, accion, estado_anterior, estado_nuevo, motivo, fecha_evento)
    VALUES
        (NEW.id_animal, 'Venta', 'Activo', 'Vendido',
         CONCAT('Baja tipo: ', NEW.tipo_baja), NEW.fecha_baja);
END$$

-- ── T3: Actualizar peso_actual_kg al insertar pesaje ─────────────────────────
CREATE TRIGGER trg_pesaje_actualiza_peso
AFTER INSERT ON tbl_pesaje
FOR EACH ROW
BEGIN
    UPDATE tbl_animal
       SET peso_actual_kg = NEW.peso_kg
     WHERE id_animal = NEW.id_animal;
END$$

-- ── T4: Cerrar detalle vaca anterior al crear uno nuevo vigente ───────────────
CREATE TRIGGER trg_vaca_cierra_anterior
BEFORE INSERT ON tbl_vaca_detalle
FOR EACH ROW
BEGIN
    IF NEW.es_vigente = TRUE THEN
        UPDATE tbl_vaca_detalle
           SET es_vigente = FALSE,
               fecha_fin  = NEW.fecha_inicio
         WHERE id_animal  = NEW.id_animal
           AND es_vigente = TRUE;
    END IF;
END$$

-- ── T5: Cerrar detalle toro anterior al crear uno nuevo vigente ───────────────
CREATE TRIGGER trg_toro_cierra_anterior
BEFORE INSERT ON tbl_toro_detalle
FOR EACH ROW
BEGIN
    IF NEW.es_vigente = TRUE THEN
        UPDATE tbl_toro_detalle
           SET es_vigente = FALSE,
               fecha_fin  = NEW.fecha_inicio
         WHERE id_animal  = NEW.id_animal
           AND es_vigente = TRUE;
    END IF;
END$$

-- ── T6: Cerrar detalle ternero anterior al crear uno nuevo vigente ────────────
CREATE TRIGGER trg_ternero_cierra_anterior
BEFORE INSERT ON tbl_ternero_detalle
FOR EACH ROW
BEGIN
    IF NEW.es_vigente = TRUE THEN
        UPDATE tbl_ternero_detalle
           SET es_vigente = FALSE,
               fecha_fin  = NEW.fecha_inicio
         WHERE id_animal  = NEW.id_animal
           AND es_vigente = TRUE;
    END IF;
END$$

-- ── T7: Actualizar stock de insumo al registrar movimiento ───────────────────
CREATE TRIGGER trg_insumo_actualiza_stock
AFTER INSERT ON tbl_movimiento_insumo
FOR EACH ROW
BEGIN
    IF NEW.tipo_movimiento IN ('Compra','Producción') THEN
        UPDATE tbl_insumo
           SET stock_actual = stock_actual + NEW.cantidad
         WHERE id_insumo = NEW.id_insumo;
    ELSEIF NEW.tipo_movimiento IN ('Venta','Consumo') THEN
        UPDATE tbl_insumo
           SET stock_actual = stock_actual - NEW.cantidad
         WHERE id_insumo = NEW.id_insumo;
    -- Ajuste: la cantidad puede ser positiva o negativa; en este modelo
    -- siempre es positiva (CHECK), así que Ajuste suma. Maneja el signo
    -- desde el backend si necesitas ajustes negativos.
    END IF;
END$$

-- ── T8: Auditoría de alertas — registrar en tbl_auditoria_alerta al crear ────
CREATE TRIGGER trg_alerta_auditoria_insert
AFTER INSERT ON tbl_alerta
FOR EACH ROW
BEGIN
    INSERT INTO tbl_auditoria_alerta
        (id_alerta, modulo, id_animal, id_origen, tipo, descripcion,
         prioridad, fecha_programada, estado_anterior, estado_nuevo, accion_auditoria, usuario_auditor)
    VALUES
        (NEW.id_alerta, NEW.modulo, NEW.id_animal, NEW.id_origen, NEW.tipo,
         NEW.descripcion, NEW.prioridad, NEW.fecha_programada,
         'N/A', NEW.estado, 'Creada', USER());
END$$

-- ── T9: Auditoría de alertas — registrar cambios de estado ───────────────────
CREATE TRIGGER trg_alerta_auditoria_update
AFTER UPDATE ON tbl_alerta
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado THEN
        INSERT INTO tbl_auditoria_alerta
            (id_alerta, modulo, id_animal, id_origen, tipo, descripcion,
             prioridad, fecha_programada, estado_anterior, estado_nuevo,
             accion_auditoria, usuario_auditor)
        VALUES
            (NEW.id_alerta, NEW.modulo, NEW.id_animal, NEW.id_origen, NEW.tipo,
             NEW.descripcion, NEW.prioridad, NEW.fecha_programada,
             OLD.estado, NEW.estado,
             CASE NEW.estado
                 WHEN 'Atendida'  THEN 'Atendida'
                 WHEN 'Cancelada' THEN 'Cancelada'
                 ELSE 'Modificada'
             END,
             USER());
    END IF;
END$$

-- ── T10: Auditoría de alertas — preservar registro al eliminar ────────────────
CREATE TRIGGER trg_alerta_auditoria_delete
BEFORE DELETE ON tbl_alerta
FOR EACH ROW
BEGIN
    INSERT INTO tbl_auditoria_alerta
        (id_alerta, modulo, id_animal, id_origen, tipo, descripcion,
         prioridad, fecha_programada, estado_anterior, estado_nuevo,
         accion_auditoria, usuario_auditor)
    VALUES
        (OLD.id_alerta, OLD.modulo, OLD.id_animal, OLD.id_origen, OLD.tipo,
         OLD.descripcion, OLD.prioridad, OLD.fecha_programada,
         OLD.estado, NULL, 'Eliminada', USER());
END$$

-- ── T11: Actualizar manga_actual en tbl_animal al mover ──────────────────────
CREATE TRIGGER trg_movimiento_actualiza_manga
AFTER INSERT ON tbl_movimiento_manga
FOR EACH ROW
BEGIN
    UPDATE tbl_animal
       SET id_manga_actual = NEW.id_manga_destino
     WHERE id_animal = NEW.id_animal;
END$$

DELIMITER ;

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 17: STORED PROCEDURES
-- ════════════════════════════════════════════════════════════════════════════

DELIMITER $$

-- ── SP1: Obtener o crear causa desde texto libre del formulario ───────────────
CREATE PROCEDURE sp_obtener_o_crear_causa(
    IN  p_principal    VARCHAR(50),
    IN  p_detalle      VARCHAR(255),
    OUT p_id_causa_out INT
)
BEGIN
    SELECT id_causa INTO p_id_causa_out
      FROM tbl_causa
     WHERE causa_principal = p_principal
       AND (detalle_causa = p_detalle OR (detalle_causa IS NULL AND p_detalle IS NULL))
     LIMIT 1;

    IF p_id_causa_out IS NULL THEN
        INSERT INTO tbl_causa (causa_principal, detalle_causa)
        VALUES (p_principal, p_detalle);
        SET p_id_causa_out = LAST_INSERT_ID();
    END IF;
END$$

-- ── SP2: Registrar animal + su primer detalle en una transacción ──────────────
CREATE PROCEDURE sp_registrar_animal(
    IN  p_tipo         VARCHAR(20),
    IN  p_arete        VARCHAR(50),
    IN  p_trazabilidad VARCHAR(20),
    IN  p_sexo         CHAR(1),
    IN  p_id_raza      INT,
    IN  p_id_manga     INT,
    IN  p_id_proced    INT,
    IN  p_fecha_nac    DATE,
    IN  p_peso         DECIMAL(7,2),
    IN  p_proposito    VARCHAR(40),
    IN  p_id_madre     INT,
    IN  p_id_padre     INT,
    IN  p_id_usuario   INT,
    OUT p_id_animal    INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;

    INSERT INTO tbl_animal
        (tipo_animal, arete, trazabilidad, sexo, id_raza,
         id_manga_actual, id_procedencia, fecha_nacimiento, peso_actual_kg)
    VALUES
        (p_tipo, p_arete, p_trazabilidad, p_sexo, p_id_raza,
         p_id_manga, p_id_proced, p_fecha_nac, p_peso);

    SET p_id_animal = LAST_INSERT_ID();

    CASE p_tipo
        WHEN 'Vaca' THEN
            INSERT INTO tbl_vaca_detalle (id_animal)
            VALUES (p_id_animal);
        WHEN 'Toro' THEN
            INSERT INTO tbl_toro_detalle (id_animal, tipo_uso, id_usuario_registro)
            VALUES (p_id_animal, COALESCE(p_proposito,'Semental'), p_id_usuario);
        WHEN 'Ternero' THEN
            INSERT INTO tbl_ternero_detalle (id_animal, id_madre, id_padre, peso_nacimiento_kg)
            VALUES (p_id_animal, p_id_madre, p_id_padre, p_peso);
        ELSE
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Tipo de animal inválido: use Vaca, Toro o Ternero';
    END CASE;

    INSERT INTO tbl_bitacora (id_usuario, accion, tabla_afectada, id_registro, detalle)
    VALUES (p_id_usuario, 'INSERT', 'tbl_animal', p_id_animal,
            JSON_OBJECT('tipo', p_tipo, 'arete', p_arete));

    COMMIT;
END$$

-- ── SP3: Promover ternero a vaca o toro ──────────────────────────────────────
CREATE PROCEDURE sp_promover_ternero(
    IN p_id_animal   INT,
    IN p_nuevo_tipo  VARCHAR(10),
    IN p_proposito   VARCHAR(40),
    IN p_id_usuario  INT
)
BEGIN
    DECLARE v_sexo CHAR(1);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;

    SELECT sexo INTO v_sexo FROM tbl_animal WHERE id_animal = p_id_animal;

    IF (p_nuevo_tipo = 'Vaca' AND v_sexo <> 'F')
       OR (p_nuevo_tipo = 'Toro' AND v_sexo <> 'M') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Sexo del animal incompatible con la promoción solicitada';
    END IF;

    UPDATE tbl_ternero_detalle
       SET es_vigente = FALSE, fecha_fin = CURRENT_DATE
     WHERE id_animal = p_id_animal AND es_vigente = TRUE;

    UPDATE tbl_animal
       SET tipo_animal = p_nuevo_tipo
     WHERE id_animal = p_id_animal;

    IF p_nuevo_tipo = 'Vaca' THEN
        INSERT INTO tbl_vaca_detalle (id_animal) VALUES (p_id_animal);
    ELSE
        INSERT INTO tbl_toro_detalle (id_animal, tipo_uso, id_usuario_registro)
        VALUES (p_id_animal, COALESCE(p_proposito,'Semental'), p_id_usuario);
    END IF;

    INSERT INTO tbl_bitacora (id_usuario, accion, tabla_afectada, id_registro, detalle)
    VALUES (p_id_usuario, 'PROMOTE', 'tbl_animal', p_id_animal,
            JSON_OBJECT('nuevo_tipo', p_nuevo_tipo));

    COMMIT;
END$$

-- ── SP4: Registrar alerta y registrarla en auditoría ─────────────────────────
CREATE PROCEDURE sp_crear_alerta(
    IN p_modulo          VARCHAR(50),
    IN p_id_animal       INT,
    IN p_tipo            VARCHAR(120),
    IN p_descripcion     TEXT,
    IN p_prioridad       VARCHAR(20),
    IN p_fecha_prog      DATE,
    IN p_enviar_correo   BOOLEAN,
    IN p_id_usuario      INT,
    OUT p_id_alerta_out  BIGINT
)
BEGIN
    INSERT INTO tbl_alerta
        (modulo, id_animal, tipo, descripcion, prioridad,
         fecha_programada, enviar_correo, id_usuario_atiende)
    VALUES
        (p_modulo, p_id_animal, p_tipo, p_descripcion, p_prioridad,
         p_fecha_prog, p_enviar_correo, p_id_usuario);

    SET p_id_alerta_out = LAST_INSERT_ID();
    -- El trigger trg_alerta_auditoria_insert registra automáticamente en auditoría
END$$

-- ── SP5: Atender alerta ───────────────────────────────────────────────────────
CREATE PROCEDURE sp_atender_alerta(
    IN p_id_alerta   BIGINT,
    IN p_id_usuario  INT
)
BEGIN
    UPDATE tbl_alerta
       SET estado             = 'Atendida',
           fecha_atendida     = NOW(),
           notificacion_vista = TRUE,
           id_usuario_atiende = p_id_usuario
     WHERE id_alerta = p_id_alerta
       AND estado    = 'Pendiente';
    -- El trigger trg_alerta_auditoria_update registra el cambio automáticamente
END$$

DELIMITER ;

-- ════════════════════════════════════════════════════════════════════════════
--  BLOQUE 18: VISTAS
-- ════════════════════════════════════════════════════════════════════════════

-- VW1: Animal completo con su detalle vigente según tipo
CREATE OR REPLACE VIEW vw_animal_completo AS
SELECT
    a.id_animal,
    a.arete,
    a.trazabilidad,
    a.tipo_animal,
    a.sexo,
    r.nombre_raza,
    r.proposito        AS proposito_raza,
    m.nombre           AS manga_actual,
    m.numero_manga,
    p.nombre           AS procedencia,
    a.fecha_nacimiento,
    TIMESTAMPDIFF(MONTH, a.fecha_nacimiento, CURDATE()) AS edad_meses,
    a.peso_actual_kg,
    a.estado_animal,
    -- Vaca
    vd.estado_ordeno,
    vd.estado_reproductivo,
    -- Toro
    td.tipo_uso,
    td.activo_reproduccion,
    td.libido_evaluacion,
    -- Ternero
    tnd.estado_lactancia,
    tnd.peso_nacimiento_kg,
    tnd.peso_destete_kg
FROM tbl_animal a
LEFT JOIN tbl_raza           r   ON a.id_raza        = r.id_raza
LEFT JOIN tbl_manga          m   ON a.id_manga_actual = m.id_manga
LEFT JOIN tbl_procedencia    p   ON a.id_procedencia  = p.id_procedencia
LEFT JOIN tbl_vaca_detalle   vd  ON a.id_animal = vd.id_animal  AND vd.es_vigente = TRUE
LEFT JOIN tbl_toro_detalle   td  ON a.id_animal = td.id_animal  AND td.es_vigente = TRUE
LEFT JOIN tbl_ternero_detalle tnd ON a.id_animal = tnd.id_animal AND tnd.es_vigente = TRUE;

-- VW2: Inventario por manga con ocupación
CREATE OR REPLACE VIEW vw_inventario_mangas AS
SELECT
    m.id_manga,
    m.numero_manga,
    m.nombre,
    m.funcion,
    m.capacidad_max,
    COUNT(a.id_animal) AS cantidad_actual,
    ROUND(COUNT(a.id_animal) / NULLIF(m.capacidad_max,0) * 100, 1) AS pct_ocupacion
FROM tbl_manga m
LEFT JOIN tbl_animal a
    ON a.id_manga_actual = m.id_manga
    AND a.estado_animal NOT IN ('Fallecido','Vendido')
GROUP BY m.id_manga, m.numero_manga, m.nombre, m.funcion, m.capacidad_max;

-- VW3: Producción de leche de los últimos 30 días
CREATE OR REPLACE VIEW vw_produccion_reciente AS
SELECT
    a.id_animal,
    a.arete,
    r.nombre_raza,
    m.nombre     AS manga,
    pl.fecha_ordeno,
    pl.litros_manana,
    pl.litros_tarde,
    pl.total_litros
FROM tbl_produccion_leche pl
JOIN tbl_animal a ON pl.id_animal = a.id_animal
JOIN tbl_raza   r ON a.id_raza    = r.id_raza
LEFT JOIN tbl_manga m ON a.id_manga_actual = m.id_manga
WHERE pl.fecha_ordeno >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
ORDER BY pl.fecha_ordeno DESC;

-- VW4: Alertas pendientes con datos del animal
CREATE OR REPLACE VIEW vw_alertas_pendientes AS
SELECT
    al.id_alerta,
    al.modulo,
    al.tipo,
    al.descripcion,
    al.prioridad,
    al.fecha_programada,
    al.enviar_correo,
    al.correo_enviado,
    al.notificacion_vista,
    a.arete        AS arete_animal,
    a.tipo_animal,
    a.estado_animal,
    u.nombre_completo AS usuario_asignado
FROM tbl_alerta al
LEFT JOIN tbl_animal  a ON al.id_animal          = a.id_animal
LEFT JOIN tbl_usuario u ON al.id_usuario_atiende = u.id_usuario
WHERE al.estado = 'Pendiente'
ORDER BY FIELD(al.prioridad,'Urgente','Normal','Baja'), al.fecha_programada;

-- VW5: Historial reproductivo de vacas
CREATE OR REPLACE VIEW vw_historial_reproductivo AS
SELECT
    a.arete,
    a.id_animal,
    er.tipo_evento,
    er.fecha_evento,
    er.resultado_palp,
    er.fecha_estimada_parto,
    er.estado_resultado,
    CONCAT(c.causa_principal, IFNULL(CONCAT(' — ', c.detalle_causa),'')) AS causa,
    er.observaciones
FROM tbl_evento_reproductivo er
JOIN tbl_animal a ON er.id_animal = a.id_animal
LEFT JOIN tbl_causa c ON er.id_causa = c.id_causa
ORDER BY er.id_animal, er.fecha_evento DESC;

-- VW6: Mortalidad con causa y animal
CREATE OR REPLACE VIEW vw_mortalidad AS
SELECT
    mo.id_mortalidad,
    a.arete,
    a.tipo_animal,
    r.nombre_raza,
    mo.fecha_muerte,
    c.causa_principal,
    c.detalle_causa,
    mo.observacion,
    u.nombre_completo AS registrado_por
FROM tbl_mortalidad mo
JOIN tbl_animal  a ON mo.id_animal  = a.id_animal
JOIN tbl_raza    r ON a.id_raza     = r.id_raza
JOIN tbl_causa   c ON mo.id_causa   = c.id_causa
LEFT JOIN tbl_usuario u ON mo.id_usuario = u.id_usuario
ORDER BY mo.fecha_muerte DESC;

-- VW7: Insumos con alerta de stock bajo
CREATE OR REPLACE VIEW vw_stock_bajo AS
SELECT
    id_insumo,
    nombre,
    unidad,
    stock_actual,
    stock_minimo,
    ROUND(stock_actual - stock_minimo, 2) AS diferencia
FROM tbl_insumo
WHERE activo = TRUE
  AND stock_actual <= stock_minimo
ORDER BY diferencia;

-- VW8: Auditoría completa de alertas
CREATE OR REPLACE VIEW vw_auditoria_alertas AS
SELECT
    aa.id_auditoria,
    aa.id_alerta,
    aa.modulo,
    aa.tipo,
    aa.prioridad,
    aa.fecha_programada,
    aa.estado_anterior,
    aa.estado_nuevo,
    aa.accion_auditoria,
    aa.fecha_auditoria,
    aa.usuario_auditor,
    a.arete AS arete_animal
FROM tbl_auditoria_alerta aa
LEFT JOIN tbl_animal a ON aa.id_animal = a.id_animal
ORDER BY aa.fecha_auditoria DESC;

-- ════════════════════════════════════════════════════════════════════════════
--  PASO 4: TRIGGERS (Alineados)
-- ════════════════════════════════════════════════════════════════════════════

DELIMITER $$

CREATE TRIGGER trg_insumo_compra_contabilidad
AFTER INSERT ON tbl_movimiento_insumo
FOR EACH ROW
BEGIN
    DECLARE v_nombre_insumo VARCHAR(120);

    IF NEW.tipo_movimiento = 'Compra' AND NEW.precio_unitario > 0 THEN
        SELECT nombre INTO v_nombre_insumo
          FROM tbl_insumo WHERE id_insumo = NEW.id_insumo;

        INSERT INTO tbl_transaccion_financiera
            (categoria, fecha_transaccion, concepto, descripcion,
             monto, estado, tipo_origen, id_mov_insumo, id_usuario)
        VALUES
            ('gasto', NEW.fecha_movimiento,
             CONCAT('Compra: ', COALESCE(v_nombre_insumo, 'Insumo Desconocido')),
             CONCAT('Proveedor: ', COALESCE(NEW.proveedor, 'N/A'),
                    ' | Cant: ', NEW.cantidad, ' | Factura: ',
                    COALESCE(NEW.factura_url, 'S/F')),
             NEW.cantidad * NEW.precio_unitario,
             'ejecutado', 'Compra Insumo', NEW.id_mov_insumo, NEW.id_usuario);
    END IF;
END$$

CREATE TRIGGER trg_insumo_venta_contabilidad
AFTER INSERT ON tbl_movimiento_insumo
FOR EACH ROW
BEGIN
    DECLARE v_nombre_insumo VARCHAR(120);

    IF NEW.tipo_movimiento = 'Venta' AND NEW.precio_unitario > 0 AND NEW.destino_venta = 'Venta' THEN
        SELECT nombre INTO v_nombre_insumo
          FROM tbl_insumo WHERE id_insumo = NEW.id_insumo;

        INSERT INTO tbl_transaccion_financiera
            (categoria, fecha_transaccion, concepto, descripcion,
             monto, estado, tipo_origen, id_mov_insumo, id_usuario)
        VALUES
            ('ingreso', NEW.fecha_movimiento,
             CONCAT('Venta: ', COALESCE(v_nombre_insumo, 'Insumo Desconocido')),
             CONCAT('Cliente: ', COALESCE(NEW.cliente, 'N/A'),
                    ' | Cant: ', NEW.cantidad),
             NEW.cantidad * NEW.precio_unitario,
             'ejecutado', 'Venta Insumo', NEW.id_mov_insumo, NEW.id_usuario);
    END IF;
END$$

DELIMITER ;

-- ════════════════════════════════════════════════════════════════════════════
--  PASO 5: STORED PROCEDURES
-- ════════════════════════════════════════════════════════════════════════════

DELIMITER $$

CREATE PROCEDURE sp_registrar_ingreso_venta_animal(
    IN  p_id_baja       BIGINT,
    IN  p_precio        DECIMAL(12,2),
    IN  p_comision_pct  DECIMAL(5,2),
    IN  p_notas         VARCHAR(255),
    IN  p_id_usuario    INT,
    OUT p_id_trans_out  BIGINT
)
BEGIN
    DECLARE v_arete        VARCHAR(50);
    DECLARE v_fecha_baja   DATE;
    DECLARE v_comprador    VARCHAR(120);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN 
        ROLLBACK; 
        RESIGNAL; 
    END;

    START TRANSACTION;

    SELECT a.arete, b.fecha_baja, b.comprador
      INTO v_arete, v_fecha_baja, v_comprador
      FROM tbl_baja_animal b
      JOIN tbl_animal      a ON b.id_animal = a.id_animal
     WHERE b.id_baja = p_id_baja;

    INSERT INTO tbl_transaccion_financiera
        (categoria, fecha_transaccion, concepto, descripcion,
         monto, estado, tipo_origen, id_usuario)
    VALUES
        ('ingreso', v_fecha_baja,
         CONCAT('Venta animal: ', v_arete),
         CONCAT('Comprador: ', COALESCE(v_comprador, 'N/A')),
         p_precio,
         'ejecutado', 'Venta Animal', p_id_usuario);

    SET p_id_trans_out = LAST_INSERT_ID();

    INSERT INTO tbl_transaccion_animal
        (id_transaccion, id_baja, precio_acordado, comision_pct, notas)
    VALUES
        (p_id_trans_out, p_id_baja, p_precio, p_comision_pct, p_notas);

    COMMIT;
END$$

CREATE PROCEDURE sp_liquidar_leche(
    IN  p_fecha_inicio  DATE,
    IN  p_fecha_fin     DATE,
    IN  p_precio_litro  DECIMAL(8,4),
    IN  p_descuentos    DECIMAL(12,2),
    IN  p_comprador     VARCHAR(120),
    IN  p_notas         VARCHAR(255),
    IN  p_id_usuario    INT,
    OUT p_id_trans_out  BIGINT
)
BEGIN
    DECLARE v_total_litros DECIMAL(10,2);
    DECLARE v_ingreso_neto DECIMAL(12,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN 
        ROLLBACK; 
        RESIGNAL; 
    END;

    START TRANSACTION;

    SELECT COALESCE(SUM(total_litros), 0)
      INTO v_total_litros
      FROM tbl_produccion_leche
     WHERE fecha_ordeno BETWEEN p_fecha_inicio AND p_fecha_fin;

    IF v_total_litros = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No hay registros de producción en el período indicado';
    END IF;

    SET v_ingreso_neto = (v_total_litros * p_precio_litro) - p_descuentos;

    INSERT INTO tbl_transaccion_financiera
        (categoria, fecha_transaccion, concepto, descripcion,
         monto, estado, tipo_origen, id_usuario)
    VALUES
        ('ingreso', p_fecha_fin,
         CONCAT('Liquidación leche: ', p_fecha_inicio, ' → ', p_fecha_fin),
         CONCAT(v_total_litros, ' lts × $', p_precio_litro, ' | Comprador: ', COALESCE(p_comprador, 'N/A')),
         v_ingreso_neto,
         'ejecutado', 'Ingreso Leche', p_id_usuario);

    SET p_id_trans_out = LAST_INSERT_ID();

    INSERT INTO tbl_transaccion_leche
        (id_transaccion, fecha_inicio, fecha_fin, total_litros,
         precio_litro, descuentos, comprador, notas)
    VALUES
        (p_id_trans_out, p_fecha_inicio, p_fecha_fin, v_total_litros,
         p_precio_litro, p_descuentos, p_comprador, p_notas);

    COMMIT;
END$$

DELIMITER ;

-- ════════════════════════════════════════════════════════════════════════════
--  PASO 6: VISTAS (Resumen Corregido sin desglose duplicado de totales por mes)
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW vw_resumen_financiero_mensual AS
SELECT
    YEAR(fecha_transaccion)                                      AS anio,
    MONTH(fecha_transaccion)                                     AS mes,
    SUM(CASE WHEN categoria = 'ingreso' THEN monto ELSE 0 END)   AS total_ingresos,
    SUM(CASE WHEN categoria = 'gasto'   THEN monto ELSE 0 END)   AS total_gastos,
    SUM(CASE WHEN categoria = 'ingreso' THEN monto 
             WHEN categoria = 'gasto'   THEN -monto ELSE 0 END)  AS balance
FROM tbl_transaccion_financiera
GROUP BY YEAR(fecha_transaccion), MONTH(fecha_transaccion)
ORDER BY anio DESC, mes DESC;

-- VW9: Expediente Sanitario de Animales
CREATE OR REPLACE VIEW vw_expediente_sanitario AS
SELECT 
    rta.id_animal,
    a.arete,
    rs.fecha_aplicacion,
    rs.categoria AS tipo_registro,
    CONCAT(
        COALESCE(c.detalle_causa, c.causa_principal, 'Sin diagnóstico'), 
        ' — ', 
        COALESCE(ps.nombre, 'Sin producto')
    ) AS detalle_tratamiento,
    CONCAT(rs.dosis_valor, ' ', rs.dosis_unidad) AS dosis_aplicada,
    col.nombre AS veterinario_responsable,
    prog.fecha_programada AS proxima_dosis_revision,
    rs.id_registro_san,
    rta.estado_aplicacion
FROM tbl_registro_sanitario_animal rta
JOIN tbl_registro_sanitario rs ON rta.id_registro_san = rs.id_registro_san
JOIN tbl_animal a ON rta.id_animal = a.id_animal
LEFT JOIN tbl_producto_sanitario ps ON rs.id_producto = ps.id_producto
LEFT JOIN tbl_causa c ON rs.id_causa = c.id_causa
LEFT JOIN tbl_colaborador col ON rs.id_veterinario = col.id_colaborador
LEFT JOIN tbl_programacion_sanitaria prog ON rs.id_registro_san = prog.id_registro_san 
    AND prog.estado = 'Pendiente';

-- VW10: Expediente Reproductivo de Animales
CREATE OR REPLACE VIEW vw_expediente_reproductivo AS
SELECT 
    er.id_animal,
    a.arete,
    er.tipo_evento AS evento,
    er.fecha_evento AS fecha,
    -- Combinamos la fase, causa u observaciones para el campo Detalle / Tipo / Fase
    TRIM(BOTH ' - ' FROM CONCAT_WS(' - ', 
        er.fase_palpacion, 
        c.detalle_causa, 
        er.observaciones
    )) AS detalle,
    -- Se muestra el número de pajilla (IA) o el arete del semental (Monta)
    COALESCE(er.numero_pajilla, toro.arete, '-') AS semental_pajilla,
    -- Generamos un estado amigable para la interfaz basado en los resultados
    CASE 
        WHEN er.resultado_palp = 'Preñez confirmada' THEN 'Confirmada'
        WHEN er.resultado_palp = 'Preñez provisional' THEN 'Provisional'
        WHEN er.resultado_palp IS NOT NULL AND er.resultado_palp != 'Sin evaluar' THEN er.resultado_palp
        WHEN er.tipo_evento = 'Parto' AND er.estado_resultado = 'Realizado' THEN 'Exitoso'
        WHEN er.tipo_evento = 'Aborto' THEN 'Aborto'
        ELSE er.estado_resultado 
    END AS estado,
    er.id_evento_rep
FROM tbl_evento_reproductivo er
JOIN tbl_animal a ON er.id_animal = a.id_animal
LEFT JOIN tbl_animal toro ON er.id_toro = toro.id_animal
LEFT JOIN tbl_causa c ON er.id_causa = c.id_causa;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                     FIN DEL SCRIPT v3.0 — HOFLOC.SA                     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝