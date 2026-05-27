
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

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- T12 Reproducción Automatización de ciclos reproductivos
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DELIMITER $$
CREATE TRIGGER trg_ciclo_estado_vaca_y_alertas
AFTER UPDATE ON tbl_ciclo_reproductivo
FOR EACH ROW
BEGIN
    -- Detectar cambio de fase en el ciclo
    IF OLD.estado_ciclo <> NEW.estado_ciclo THEN
        
        -- A) Sincronizar tabla tbl_vaca_detalle (estado reproductivo actual)
        IF NEW.estado_ciclo IN ('Preñez Provisional', 'Preñez Confirmada') THEN
            UPDATE tbl_vaca_detalle SET estado_reproductivo = 'Preñada' 
            WHERE id_animal = NEW.id_animal AND es_vigente = TRUE;
        ELSEIF NEW.estado_ciclo IN ('Vacía', 'Parto Exitoso', 'Abortado') THEN
            UPDATE tbl_vaca_detalle SET estado_reproductivo = 'Vacía' 
            WHERE id_animal = NEW.id_animal AND es_vigente = TRUE;
        END IF;
        
        -- B) Completar Alertas pendientes asociadas a la fase que se acaba de superar
        IF NEW.estado_ciclo IN ('Preñez Provisional', 'Vacía') AND OLD.estado_ciclo = 'Pendiente Palpación 1' THEN
            UPDATE tbl_alerta_reproductiva SET estado_alerta = 'Completada' 
            WHERE id_ciclo = NEW.id_ciclo AND tipo_alerta = 'Palpación 1' AND estado_alerta = 'Pendiente';
        END IF;
        
        IF NEW.estado_ciclo IN ('Preñez Confirmada', 'Vacía') AND OLD.estado_ciclo = 'Preñez Provisional' THEN
            UPDATE tbl_alerta_reproductiva SET estado_alerta = 'Completada' 
            WHERE id_ciclo = NEW.id_ciclo AND tipo_alerta = 'Palpación 2' AND estado_alerta = 'Pendiente';
        END IF;
        
        IF NEW.estado_ciclo IN ('Parto Exitoso', 'Abortado') AND OLD.estado_ciclo = 'Preñez Confirmada' THEN
            UPDATE tbl_alerta_reproductiva SET estado_alerta = 'Completada' 
            WHERE id_ciclo = NEW.id_ciclo AND tipo_alerta = 'Parto Estimado' AND estado_alerta = 'Pendiente';
        END IF;
        
    END IF;
END$$
DELIMITER ;

-- ════════════════════════════════════════════════════════════════════════════
-- T13 Trigger para "devolver" a la vaca a su estado normal:
-- ════════════════════════════════════════════════════════════════════════════
DELIMITER $$
CREATE TRIGGER trg_ciclo_borrar_vaca
AFTER DELETE ON tbl_ciclo_reproductivo
FOR EACH ROW
BEGIN
    -- Si borramos un ciclo por error, asegurarnos de que la vaca vuelva a estado 'Vacía'
    UPDATE tbl_vaca_detalle SET estado_reproductivo = 'Vacía' 
    WHERE id_animal = OLD.id_animal AND es_vigente = TRUE;
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

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- STORED PROCEDURES Reproducción (Controladores de Estado)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DELIMITER $$
-- 01 | Iniciar Ciclo
CREATE PROCEDURE sp_iniciar_ciclo(
    IN p_id_animal INT,
    IN p_fecha_inicio DATE,
    IN p_tipo_evento VARCHAR(50),
    IN p_id_veterinario INT
)
BEGIN
    DECLARE v_activos INT;
    DECLARE v_id_ciclo INT;
    
    -- Validar que la vaca no tenga un ciclo ya en curso
    SELECT COUNT(*) INTO v_activos FROM tbl_ciclo_reproductivo 
    WHERE id_animal = p_id_animal 
    AND estado_ciclo NOT IN ('Parto Exitoso', 'Abortado', 'Vacía');
    
    IF v_activos > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La vaca ya tiene un ciclo reproductivo activo.';
    END IF;
    
    INSERT INTO tbl_ciclo_reproductivo (
        id_animal, fecha_inicio, tipo_evento, id_veterinario_inicio,
        fecha_estimada_palp1, fecha_estimada_palp2, fecha_estimada_parto,
        estado_ciclo
    ) VALUES (
        p_id_animal, p_fecha_inicio, p_tipo_evento, p_id_veterinario,
        DATE_ADD(p_fecha_inicio, INTERVAL 30 DAY),
        DATE_ADD(p_fecha_inicio, INTERVAL 60 DAY),
        DATE_ADD(p_fecha_inicio, INTERVAL 283 DAY),
        'Pendiente Palpación 1'
    );
    
    SET v_id_ciclo = LAST_INSERT_ID();
    
    -- Crear Alerta 1
    INSERT INTO tbl_alerta_reproductiva (id_ciclo, id_animal, tipo_alerta, fecha_programada)
    VALUES (v_id_ciclo, p_id_animal, 'Palpación 1', DATE_ADD(p_fecha_inicio, INTERVAL 30 DAY));
END$$
-- 02 | Registrar Palpación 1
CREATE PROCEDURE sp_registrar_palpacion1(
    IN p_id_ciclo INT,
    IN p_fecha_palpacion DATE,
    IN p_resultado VARCHAR(20),
    IN p_id_veterinario INT
)
BEGIN
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_id_animal INT;
    
    SELECT estado_ciclo, id_animal INTO v_estado_actual, v_id_animal 
    FROM tbl_ciclo_reproductivo WHERE id_ciclo = p_id_ciclo FOR UPDATE;
    
    IF v_estado_actual != 'Pendiente Palpación 1' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ciclo debe estar en "Pendiente Palpación 1" para realizar esta acción.';
    END IF;
    
    IF p_resultado = 'Preñada' THEN
        UPDATE tbl_ciclo_reproductivo 
        SET fecha_palpacion1 = p_fecha_palpacion, resultado_palpacion1 = p_resultado,
            id_veterinario_palp1 = p_id_veterinario, estado_ciclo = 'Preñez Provisional'
        WHERE id_ciclo = p_id_ciclo;
        
        -- Alerta 2 (Palpación 2)
        INSERT INTO tbl_alerta_reproductiva (id_ciclo, id_animal, tipo_alerta, fecha_programada)
        SELECT id_ciclo, id_animal, 'Palpación 2', fecha_estimada_palp2 
        FROM tbl_ciclo_reproductivo WHERE id_ciclo = p_id_ciclo;
        
    ELSEIF p_resultado = 'Vacía' THEN
        UPDATE tbl_ciclo_reproductivo 
        SET fecha_palpacion1 = p_fecha_palpacion, resultado_palpacion1 = p_resultado,
            id_veterinario_palp1 = p_id_veterinario, estado_ciclo = 'Vacía'
        WHERE id_ciclo = p_id_ciclo;
        
        -- Alerta Celo (+21 días de hoy)
        INSERT INTO tbl_alerta_reproductiva (id_ciclo, id_animal, tipo_alerta, fecha_programada)
        VALUES (p_id_ciclo, v_id_animal, 'Seguimiento de Celo', DATE_ADD(CURDATE(), INTERVAL 21 DAY));
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Resultado inválido. Utilice "Preñada" o "Vacía".';
    END IF;
END$$
-- RF-03 | Registrar Palpación 2
CREATE PROCEDURE sp_registrar_palpacion2(
    IN p_id_ciclo INT,
    IN p_fecha_palpacion DATE,
    IN p_resultado VARCHAR(20),
    IN p_id_veterinario INT
)
BEGIN
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_id_animal INT;
    
    SELECT estado_ciclo, id_animal INTO v_estado_actual, v_id_animal 
    FROM tbl_ciclo_reproductivo WHERE id_ciclo = p_id_ciclo FOR UPDATE;
    
    IF v_estado_actual != 'Preñez Provisional' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ciclo debe estar en "Preñez Provisional" para registrar Palpación 2.';
    END IF;
    
    IF p_resultado = 'Preñada' THEN
        UPDATE tbl_ciclo_reproductivo 
        SET fecha_palpacion2 = p_fecha_palpacion, resultado_palpacion2 = p_resultado,
            id_veterinario_palp2 = p_id_veterinario, estado_ciclo = 'Preñez Confirmada'
        WHERE id_ciclo = p_id_ciclo;
        
        -- Alerta Parto
        INSERT INTO tbl_alerta_reproductiva (id_ciclo, id_animal, tipo_alerta, fecha_programada)
        SELECT id_ciclo, id_animal, 'Parto Estimado', fecha_estimada_parto 
        FROM tbl_ciclo_reproductivo WHERE id_ciclo = p_id_ciclo;
        
    ELSEIF p_resultado = 'Vacía' THEN
        UPDATE tbl_ciclo_reproductivo 
        SET fecha_palpacion2 = p_fecha_palpacion, resultado_palpacion2 = p_resultado,
            id_veterinario_palp2 = p_id_veterinario, estado_ciclo = 'Vacía'
        WHERE id_ciclo = p_id_ciclo;
        
        -- Alerta Celo
        INSERT INTO tbl_alerta_reproductiva (id_ciclo, id_animal, tipo_alerta, fecha_programada)
        VALUES (p_id_ciclo, v_id_animal, 'Seguimiento de Celo', DATE_ADD(CURDATE(), INTERVAL 21 DAY));
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Resultado inválido. Utilice "Preñada" o "Vacía".';
    END IF;
END$$
-- 04 | Registrar Parto
CREATE PROCEDURE sp_registrar_parto(
    IN p_id_ciclo INT,
    IN p_fecha_parto DATE,
    IN p_resultado VARCHAR(20),
    IN p_id_veterinario INT
)
BEGIN
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_id_animal INT;
    
    SELECT estado_ciclo, id_animal INTO v_estado_actual, v_id_animal 
    FROM tbl_ciclo_reproductivo WHERE id_ciclo = p_id_ciclo FOR UPDATE;
    
    IF v_estado_actual != 'Preñez Confirmada' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El ciclo debe estar en "Preñez Confirmada" para registrar un parto.';
    END IF;
    
    IF p_resultado = 'Exitoso' THEN
        UPDATE tbl_ciclo_reproductivo 
        SET fecha_parto_real = p_fecha_parto, resultado_parto = p_resultado,
            id_veterinario_parto = p_id_veterinario, estado_ciclo = 'Parto Exitoso'
        WHERE id_ciclo = p_id_ciclo;
        
        -- Aquí la aplicación debería llamar luego a sp_promover_ternero()
        
    ELSEIF p_resultado = 'Abortado' THEN
        UPDATE tbl_ciclo_reproductivo 
        SET fecha_parto_real = p_fecha_parto, resultado_parto = p_resultado,
            id_veterinario_parto = p_id_veterinario, estado_ciclo = 'Abortado'
        WHERE id_ciclo = p_id_ciclo;
        
        -- Alerta Celo
        INSERT INTO tbl_alerta_reproductiva (id_ciclo, id_animal, tipo_alerta, fecha_programada)
        VALUES (p_id_ciclo, v_id_animal, 'Seguimiento de Celo', DATE_ADD(CURDATE(), INTERVAL 21 DAY));
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Resultado inválido. Utilice "Exitoso" o "Abortado".';
    END IF;
END$$
DELIMITER ;
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Reproducción: PROCEDIMIENTOS ALMACENADOS DE EDICIÓN
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DELIMITER $$
-- ────────────────────────────────────────────────────────────────────────
-- SP: Editar Fase 1 (Servicio / Día 0)
-- ────────────────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_editar_servicio(
    IN p_id_ciclo INT,
    IN p_id_usuario INT,
    IN p_fecha_inicio DATE,
    IN p_tipo_evento VARCHAR(50),
    IN p_id_toro_semental INT,
    IN p_numero_pajilla VARCHAR(50),
    IN p_id_raza_semen INT,
    IN p_id_veterinario_inicio INT,
    IN p_observaciones TEXT
)
BEGIN
    DECLARE v_estado_ciclo VARCHAR(50);
    DECLARE v_fecha_inicio_ant DATE;
    DECLARE v_tipo_evento_ant VARCHAR(50);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SELECT JSON_OBJECT('exito', false, 'mensaje', 'Error interno en la base de datos al editar el servicio.') AS resultado;
    END;
    START TRANSACTION;
    
    SELECT estado_ciclo, fecha_inicio, tipo_evento 
    INTO v_estado_ciclo, v_fecha_inicio_ant, v_tipo_evento_ant
    FROM tbl_ciclo_reproductivo WHERE id_ciclo = p_id_ciclo FOR UPDATE;
    
    IF v_estado_ciclo != 'Pendiente Palpación 1' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se puede editar el servicio si el ciclo está en Pendiente Palpación 1.';
    END IF;
    
    IF p_fecha_inicio > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha de inicio no puede ser futura.';
    END IF;
    -- Actualizar tabla principal y recalcular fechas
    UPDATE tbl_ciclo_reproductivo
    SET fecha_inicio = p_fecha_inicio,
        tipo_evento = p_tipo_evento,
        id_veterinario_inicio = p_id_veterinario_inicio,
        fecha_estimada_palp1 = DATE_ADD(p_fecha_inicio, INTERVAL 30 DAY),
        fecha_estimada_palp2 = DATE_ADD(p_fecha_inicio, INTERVAL 60 DAY),
        fecha_estimada_parto = DATE_ADD(p_fecha_inicio, INTERVAL 283 DAY)
    WHERE id_ciclo = p_id_ciclo;
    -- Actualizar alerta de Palpación 1
    IF v_fecha_inicio_ant != p_fecha_inicio THEN
        UPDATE tbl_alerta_reproductiva 
        SET fecha_programada = DATE_ADD(p_fecha_inicio, INTERVAL 30 DAY)
        WHERE id_ciclo = p_id_ciclo AND tipo_alerta = 'Palpación 1' AND estado_alerta = 'Pendiente';
        
        INSERT INTO tbl_auditoria_ciclo (id_ciclo, id_usuario, fase_editada, campo_modificado, valor_anterior, valor_nuevo, genero_cascada, descripcion_cascada)
        VALUES (p_id_ciclo, p_id_usuario, 'Servicio', 'fecha_inicio', v_fecha_inicio_ant, p_fecha_inicio, 1, 'Se recalcularon las fechas estimadas de palpación y parto, y se reprogramó la alerta de Palpación 1.');
    END IF;
    IF v_tipo_evento_ant != p_tipo_evento THEN
        INSERT INTO tbl_auditoria_ciclo (id_ciclo, id_usuario, fase_editada, campo_modificado, valor_anterior, valor_nuevo)
        VALUES (p_id_ciclo, p_id_usuario, 'Servicio', 'tipo_evento', v_tipo_evento_ant, p_tipo_evento);
    END IF;
    COMMIT;
    SELECT JSON_OBJECT('exito', true, 'mensaje', 'Servicio actualizado correctamente.', 'cascada_ejecutada', IF(v_fecha_inicio_ant != p_fecha_inicio, true, false)) AS resultado;
END$$
-- ────────────────────────────────────────────────────────────────────────
-- SP: Editar Fase 2 (Palpación 1)
-- ────────────────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_editar_palpacion1(
    IN p_id_ciclo INT,
    IN p_id_usuario INT,
    IN p_fecha_palpacion1 DATE,
    IN p_resultado_palpacion1 VARCHAR(20),
    IN p_id_veterinario_palp1 INT,
    IN p_observaciones_palp1 TEXT
)
BEGIN
    DECLARE v_estado_ciclo VARCHAR(50);
    DECLARE v_fecha_inicio DATE;
    DECLARE v_res_ant VARCHAR(20);
    DECLARE v_fecha_ant DATE;
    DECLARE v_id_animal INT;
    DECLARE v_desc_cascada TEXT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SELECT JSON_OBJECT('exito', false, 'mensaje', 'Error en la transacción al editar Palpación 1.') AS resultado;
    END;
    START TRANSACTION;
    
    SELECT estado_ciclo, fecha_inicio, resultado_palpacion1, fecha_palpacion1, id_animal 
    INTO v_estado_ciclo, v_fecha_inicio, v_res_ant, v_fecha_ant, v_id_animal
    FROM tbl_ciclo_reproductivo WHERE id_ciclo = p_id_ciclo FOR UPDATE;
    
    IF v_estado_ciclo != 'Preñez Provisional' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se puede editar Palpación 1 si el ciclo está en Preñez Provisional.';
    END IF;
    
    IF p_fecha_palpacion1 < v_fecha_inicio OR p_fecha_palpacion1 > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fecha de palpación inválida (debe ser posterior al servicio y no futura).';
    END IF;
    -- Si cambió de Preñada a Vacía (Cascada Mayor)
    IF v_res_ant = 'Preñada' AND p_resultado_palpacion1 = 'Vacía' THEN
        UPDATE tbl_ciclo_reproductivo 
        SET resultado_palpacion1 = p_resultado_palpacion1, fecha_palpacion1 = p_fecha_palpacion1, id_veterinario_palp1 = p_id_veterinario_palp1, estado_ciclo = 'Vacía'
        WHERE id_ciclo = p_id_ciclo;
        -- Cancelar alertas futuras
        UPDATE tbl_alerta_reproductiva SET estado_alerta = 'Cancelada' 
        WHERE id_ciclo = p_id_ciclo AND tipo_alerta IN ('Palpación 2', 'Parto Estimado') AND estado_alerta = 'Pendiente';
        
        -- Nueva alerta de celo
        INSERT INTO tbl_alerta_reproductiva (id_ciclo, id_animal, tipo_alerta, fecha_programada)
        VALUES (p_id_ciclo, v_id_animal, 'Seguimiento de Celo', DATE_ADD(CURDATE(), INTERVAL 21 DAY));
        
        -- Actualizar vaca
        UPDATE tbl_vaca_detalle SET estado_reproductivo = 'Vacía' WHERE id_animal = v_id_animal AND es_vigente = TRUE;
        
        SET v_desc_cascada = 'Cambio de estado a Vacía. Se cancelaron alertas futuras y se creó Seguimiento de Celo. Vaca marcada como Vacía.';
        
        INSERT INTO tbl_auditoria_ciclo (id_ciclo, id_usuario, fase_editada, campo_modificado, valor_anterior, valor_nuevo, genero_cascada, descripcion_cascada)
        VALUES (p_id_ciclo, p_id_usuario, 'Palpación 1', 'resultado_palpacion1', v_res_ant, p_resultado_palpacion1, 1, v_desc_cascada);
        
    -- Si no cambia el resultado, pero cambia la fecha
    ELSEIF p_fecha_palpacion1 != v_fecha_ant THEN
        UPDATE tbl_ciclo_reproductivo 
        SET fecha_palpacion1 = p_fecha_palpacion1, id_veterinario_palp1 = p_id_veterinario_palp1, fecha_estimada_palp2 = DATE_ADD(p_fecha_palpacion1, INTERVAL 30 DAY)
        WHERE id_ciclo = p_id_ciclo;
        
        -- Actualizar alerta Palpación 2
        UPDATE tbl_alerta_reproductiva SET fecha_programada = DATE_ADD(p_fecha_palpacion1, INTERVAL 30 DAY)
        WHERE id_ciclo = p_id_ciclo AND tipo_alerta = 'Palpación 2' AND estado_alerta = 'Pendiente';
        
        INSERT INTO tbl_auditoria_ciclo (id_ciclo, id_usuario, fase_editada, campo_modificado, valor_anterior, valor_nuevo, genero_cascada, descripcion_cascada)
        VALUES (p_id_ciclo, p_id_usuario, 'Palpación 1', 'fecha_palpacion1', v_fecha_ant, p_fecha_palpacion1, 1, 'Se reprogramó la alerta de Palpación 2 basada en la nueva fecha de Palpación 1.');
    ELSE
        -- Solo detalles menores
        UPDATE tbl_ciclo_reproductivo SET id_veterinario_palp1 = p_id_veterinario_palp1 WHERE id_ciclo = p_id_ciclo;
    END IF;
    COMMIT;
    SELECT JSON_OBJECT('exito', true, 'mensaje', 'Palpación 1 editada.', 'cascada_ejecutada', IF(v_res_ant != p_resultado_palpacion1, true, false)) AS resultado;
END$$
-- ────────────────────────────────────────────────────────────────────────
-- SP: Editar Fase 3 (Palpación 2)
-- ────────────────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_editar_palpacion2(
    IN p_id_ciclo INT,
    IN p_id_usuario INT,
    IN p_fecha_palpacion2 DATE,
    IN p_resultado_palpacion2 VARCHAR(20),
    IN p_id_veterinario_palp2 INT,
    IN p_observaciones_palp2 TEXT
)
BEGIN
    DECLARE v_estado_ciclo VARCHAR(50);
    DECLARE v_fecha_palp1 DATE;
    DECLARE v_res_ant VARCHAR(20);
    DECLARE v_fecha_ant DATE;
    DECLARE v_id_animal INT;
    DECLARE v_desc_cascada TEXT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SELECT JSON_OBJECT('exito', false, 'mensaje', 'Error en la transacción al editar Palpación 2.') AS resultado;
    END;
    START TRANSACTION;
    
    SELECT estado_ciclo, fecha_palpacion1, resultado_palpacion2, fecha_palpacion2, id_animal 
    INTO v_estado_ciclo, v_fecha_palp1, v_res_ant, v_fecha_ant, v_id_animal
    FROM tbl_ciclo_reproductivo WHERE id_ciclo = p_id_ciclo FOR UPDATE;
    
    IF v_estado_ciclo != 'Preñez Confirmada' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se puede editar Palpación 2 si el ciclo está en Preñez Confirmada.';
    END IF;
    
    IF p_fecha_palpacion2 < v_fecha_palp1 OR p_fecha_palpacion2 > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha debe ser posterior a la Palpación 1 y no futura.';
    END IF;
    IF v_res_ant = 'Preñada' AND p_resultado_palpacion2 = 'Vacía' THEN
        UPDATE tbl_ciclo_reproductivo 
        SET resultado_palpacion2 = p_resultado_palpacion2, fecha_palpacion2 = p_fecha_palpacion2, estado_ciclo = 'Vacía'
        WHERE id_ciclo = p_id_ciclo;
        UPDATE tbl_alerta_reproductiva SET estado_alerta = 'Cancelada' 
        WHERE id_ciclo = p_id_ciclo AND tipo_alerta = 'Parto Estimado' AND estado_alerta = 'Pendiente';
        
        INSERT INTO tbl_alerta_reproductiva (id_ciclo, id_animal, tipo_alerta, fecha_programada)
        VALUES (p_id_ciclo, v_id_animal, 'Seguimiento de Celo', DATE_ADD(CURDATE(), INTERVAL 21 DAY));
        
        UPDATE tbl_vaca_detalle SET estado_reproductivo = 'Vacía' WHERE id_animal = v_id_animal AND es_vigente = TRUE;
        
        SET v_desc_cascada = 'Cambio de estado a Vacía. Se canceló alerta Parto Estimado y creó Seguimiento de Celo.';
        INSERT INTO tbl_auditoria_ciclo (id_ciclo, id_usuario, fase_editada, campo_modificado, valor_anterior, valor_nuevo, genero_cascada, descripcion_cascada)
        VALUES (p_id_ciclo, p_id_usuario, 'Palpación 2', 'resultado_palpacion2', v_res_ant, p_resultado_palpacion2, 1, v_desc_cascada);
        
    ELSEIF p_fecha_palpacion2 != v_fecha_ant THEN
        UPDATE tbl_ciclo_reproductivo SET fecha_palpacion2 = p_fecha_palpacion2 WHERE id_ciclo = p_id_ciclo;
        INSERT INTO tbl_auditoria_ciclo (id_ciclo, id_usuario, fase_editada, campo_modificado, valor_anterior, valor_nuevo)
        VALUES (p_id_ciclo, p_id_usuario, 'Palpación 2', 'fecha_palpacion2', v_fecha_ant, p_fecha_palpacion2);
    END IF;
    COMMIT;
    SELECT JSON_OBJECT('exito', true, 'mensaje', 'Palpación 2 editada.') AS resultado;
END$$
-- ────────────────────────────────────────────────────────────────────────
-- SP: Editar Fase 4 (Parto)
-- ────────────────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_editar_parto(
    IN p_id_ciclo INT,
    IN p_id_usuario INT,
    IN p_fecha_parto_real DATE,
    IN p_resultado_parto VARCHAR(20),
    IN p_id_veterinario_parto INT,
    IN p_observaciones_parto TEXT
)
BEGIN
    DECLARE v_estado_ciclo VARCHAR(50);
    DECLARE v_fecha_palp2 DATE;
    DECLARE v_res_ant VARCHAR(20);
    DECLARE v_id_animal INT;
    DECLARE v_desc_cascada TEXT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SELECT JSON_OBJECT('exito', false, 'mensaje', 'Error en transacción al editar Parto.') AS resultado;
    END;
    START TRANSACTION;
    
    SELECT estado_ciclo, fecha_palpacion2, resultado_parto, id_animal 
    INTO v_estado_ciclo, v_fecha_palp2, v_res_ant, v_id_animal
    FROM tbl_ciclo_reproductivo WHERE id_ciclo = p_id_ciclo FOR UPDATE;
    
    IF v_estado_ciclo NOT IN ('Parto Exitoso', 'Abortado') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se edita el parto si el ciclo ya finalizó.';
    END IF;
    
    IF p_fecha_parto_real < v_fecha_palp2 OR p_fecha_parto_real > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fecha de parto no puede ser anterior a Palpación 2 ni futura.';
    END IF;
    IF v_res_ant = 'Exitoso' AND p_resultado_parto = 'Abortado' THEN
        UPDATE tbl_ciclo_reproductivo SET resultado_parto = p_resultado_parto, estado_ciclo = 'Abortado' WHERE id_ciclo = p_id_ciclo;
        
        -- Alerta de Celo por aborto
        INSERT INTO tbl_alerta_reproductiva (id_ciclo, id_animal, tipo_alerta, fecha_programada)
        VALUES (p_id_ciclo, v_id_animal, 'Seguimiento de Celo', DATE_ADD(p_fecha_parto_real, INTERVAL 21 DAY));
        
        SET v_desc_cascada = 'Cambio a Abortado. Requiere eliminar cría manualmente. Generada alerta de Celo.';
        INSERT INTO tbl_auditoria_ciclo (id_ciclo, id_usuario, fase_editada, campo_modificado, valor_anterior, valor_nuevo, genero_cascada, descripcion_cascada)
        VALUES (p_id_ciclo, p_id_usuario, 'Parto', 'resultado_parto', v_res_ant, p_resultado_parto, 1, v_desc_cascada);
        
    ELSEIF v_res_ant = 'Abortado' AND p_resultado_parto = 'Exitoso' THEN
        UPDATE tbl_ciclo_reproductivo SET resultado_parto = p_resultado_parto, estado_ciclo = 'Parto Exitoso' WHERE id_ciclo = p_id_ciclo;
        
        -- Eliminar alerta de celo generada por error
        UPDATE tbl_alerta_reproductiva SET estado_alerta = 'Cancelada' WHERE id_ciclo = p_id_ciclo AND tipo_alerta = 'Seguimiento de Celo' AND estado_alerta = 'Pendiente';
        
        SET v_desc_cascada = 'Cambio a Exitoso. Alerta de Celo cancelada. Ejecutar registro de cría manualmente.';
        INSERT INTO tbl_auditoria_ciclo (id_ciclo, id_usuario, fase_editada, campo_modificado, valor_anterior, valor_nuevo, genero_cascada, descripcion_cascada)
        VALUES (p_id_ciclo, p_id_usuario, 'Parto', 'resultado_parto', v_res_ant, p_resultado_parto, 1, v_desc_cascada);
    END IF;
    COMMIT;
    SELECT JSON_OBJECT('exito', true, 'mensaje', 'Parto editado.') AS resultado;
END$$
DELIMITER ;

-- =================================================================================
-- MÓDULO SANITARIO: PROCEDIMIENTOS ALMACENADOS Y TRIGGERS DE AUTOMATIZACIÓN
-- =================================================================================

DELIMITER $$
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 1. SP: REGISTRO DE SANIDAD INDIVIDUAL (O MÚLTIPLE MANUAL)
-- Permite guardar la cabecera, detalles por vaca, cronograma futuro y datos de 
-- mastitis en una sola transacción pasando Arrays de JSON desde PHP.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE PROCEDURE sp_registrar_sanidad_individual(
    IN p_categoria VARCHAR(50),
    IN p_sub_tipo VARCHAR(80),
    IN p_proposito VARCHAR(50),
    IN p_id_producto INT,
    IN p_dosis_valor DECIMAL(8,2),
    IN p_dosis_unidad VARCHAR(20),
    IN p_fecha_aplicacion DATE,
    IN p_repeticion VARCHAR(50),
    IN p_intervalo_dias INT,
    IN p_duracion_dias INT,
    IN p_id_causa INT,
    IN p_notas TEXT,
    IN p_id_veterinario INT,
    IN p_id_usuario INT,
    
    -- JSON Arrays enviados desde JS -> PHP
    IN p_animales_json JSON,     -- Ej: [41, 42, 89]
    IN p_cronograma_json JSON,   -- Ej: ["2026-06-01", "2026-06-08"]
    IN p_mastitis_json JSON      -- Ej: [{"id_animal": 41, "ad": "Sana", "pd": "Leve", "ai": "Sana", "pi": "Sana"}]
)
BEGIN
    DECLARE v_id_registro BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SELECT JSON_OBJECT('exito', false, 'mensaje', 'Error en la base de datos al registrar el tratamiento.') AS resultado;
    END;
    START TRANSACTION;
    -- 1. Insertar Cabecera
    INSERT INTO tbl_registro_sanitario (
        tipo_aplicacion, categoria, sub_tipo, proposito, id_producto,
        dosis_valor, dosis_unidad, fecha_aplicacion, repeticion, 
        intervalo_dias, duracion_dias, id_causa, notas, id_veterinario, id_usuario
    ) VALUES (
        'Individual', p_categoria, p_sub_tipo, p_proposito, p_id_producto,
        p_dosis_valor, p_dosis_unidad, p_fecha_aplicacion, COALESCE(p_repeticion, 'Única'),
        p_intervalo_dias, p_duracion_dias, p_id_causa, p_notas, p_id_veterinario, p_id_usuario
    );
    
    SET v_id_registro = LAST_INSERT_ID();
    -- 2. Insertar Detalle de Animales Afectados (Desempaquetando el JSON)
    INSERT INTO tbl_registro_sanitario_animal (id_registro_san, id_animal, estado_aplicacion, fecha_real_aplicacion)
    SELECT v_id_registro, animal_id, 'Aplicado', NOW()
    FROM JSON_TABLE(p_animales_json, '$[*]' COLUMNS(animal_id INT PATH '$')) AS jt;
    
    -- 3. Insertar Cronograma de futuras dosis (Si aplica)
    IF p_cronograma_json IS NOT NULL AND JSON_LENGTH(p_cronograma_json) > 0 THEN
        -- Crear el calendario interno del módulo sanitario
        INSERT INTO tbl_programacion_sanitaria (id_registro_san, fecha_programada, estado)
        SELECT v_id_registro, fecha_prog, 'Pendiente'
        FROM JSON_TABLE(p_cronograma_json, '$[*]' COLUMNS(fecha_prog DATE PATH '$')) AS jt;
        
        -- Crear las notificaciones globales en la tabla de alertas maestras
        INSERT INTO tbl_alerta (modulo, id_animal, tipo, descripcion, prioridad, fecha_programada)
        SELECT 'Sanidad', ja.animal_id, CONCAT('Próxima dosis: ', p_categoria), 
               CONCAT('Requiere aplicación programada de ', COALESCE(p_sub_tipo, 'tratamiento')), 
               'Normal', jc.fecha_prog
        FROM JSON_TABLE(p_animales_json, '$[*]' COLUMNS(animal_id INT PATH '$')) AS ja
        CROSS JOIN JSON_TABLE(p_cronograma_json, '$[*]' COLUMNS(fecha_prog DATE PATH '$')) AS jc;
    END IF;
    
    -- 4. Insertar Detalle Mastitis por cuartos (Si la categoría es Mastitis)
    IF p_categoria = 'Mastitis' AND p_mastitis_json IS NOT NULL AND JSON_LENGTH(p_mastitis_json) > 0 THEN
        INSERT INTO tbl_mastitis_cuartos (id_registro_san, id_animal, cuarto_ad, cuarto_pd, cuarto_ai, cuarto_pi, en_tratamiento)
        SELECT v_id_registro, m_animal_id, m_ad, m_pd, m_ai, m_pi, TRUE
        FROM JSON_TABLE(p_mastitis_json, '$[*]' COLUMNS(
            m_animal_id INT PATH '$.id_animal',
            m_ad VARCHAR(20) PATH '$.ad',
            m_pd VARCHAR(20) PATH '$.pd',
            m_ai VARCHAR(20) PATH '$.ai',
            m_pi VARCHAR(20) PATH '$.pi'
        )) AS jt;
    END IF;
    COMMIT;
    
    SELECT JSON_OBJECT('exito', true, 'mensaje', 'Registro sanitario individual creado correctamente.', 'id_registro', v_id_registro) AS resultado;
END$$
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 2. SP: REGISTRO DE SANIDAD MASIVA (POR MANGA)
-- Busca todas las vacas de la manga y hace la expansión automáticamente.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE PROCEDURE sp_registrar_sanidad_masiva(
    IN p_id_manga INT,
    IN p_categoria VARCHAR(50),
    IN p_sub_tipo VARCHAR(80),
    IN p_proposito VARCHAR(50),
    IN p_id_producto INT,
    IN p_dosis_valor DECIMAL(8,2),
    IN p_dosis_unidad VARCHAR(20),
    IN p_fecha_aplicacion DATE,
    IN p_repeticion VARCHAR(50),
    IN p_intervalo_dias INT,
    IN p_duracion_dias INT,
    IN p_id_causa INT,
    IN p_notas TEXT,
    IN p_id_veterinario INT,
    IN p_id_usuario INT,
    
    -- JSON Array del cronograma enviado desde JS -> PHP
    IN p_cronograma_json JSON
)
BEGIN
    DECLARE v_id_registro BIGINT;
    DECLARE v_vacas_afectadas INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SELECT JSON_OBJECT('exito', false, 'mensaje', 'Error en la base de datos al registrar sanidad masiva.') AS resultado;
    END;
    START TRANSACTION;
    SELECT COUNT(*) INTO v_vacas_afectadas 
    FROM tbl_animal 
    WHERE id_manga_actual = p_id_manga AND estado_animal = 'Activo';
    IF v_vacas_afectadas = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La manga seleccionada está vacía o no tiene animales activos.';
    END IF;
    -- 1. Insertar Cabecera (Tipo: Masivo)
    INSERT INTO tbl_registro_sanitario (
        tipo_aplicacion, categoria, sub_tipo, proposito, id_producto,
        dosis_valor, dosis_unidad, fecha_aplicacion, repeticion, 
        intervalo_dias, duracion_dias, id_causa, notas, id_veterinario, id_usuario
    ) VALUES (
        'Masivo', p_categoria, p_sub_tipo, p_proposito, p_id_producto,
        p_dosis_valor, p_dosis_unidad, p_fecha_aplicacion, COALESCE(p_repeticion, 'Única'),
        p_intervalo_dias, p_duracion_dias, p_id_causa, p_notas, p_id_veterinario, p_id_usuario
    );
    
    SET v_id_registro = LAST_INSERT_ID();
    -- 2. Insertar Detalle (Expansión Masiva)
    INSERT INTO tbl_registro_sanitario_animal (id_registro_san, id_animal, estado_aplicacion, fecha_real_aplicacion)
    SELECT v_id_registro, id_animal, 'Aplicado', NOW()
    FROM tbl_animal
    WHERE id_manga_actual = p_id_manga AND estado_animal = 'Activo';
    
    -- 3. Insertar Cronograma y Alertas Globales (Si aplica)
    IF p_cronograma_json IS NOT NULL AND JSON_LENGTH(p_cronograma_json) > 0 THEN
        -- Crear el calendario
        INSERT INTO tbl_programacion_sanitaria (id_registro_san, fecha_programada, estado)
        SELECT v_id_registro, fecha_prog, 'Pendiente'
        FROM JSON_TABLE(p_cronograma_json, '$[*]' COLUMNS(fecha_prog DATE PATH '$')) AS jt;
        
        -- Crear notificaciones globales
        INSERT INTO tbl_alerta (modulo, id_animal, tipo, descripcion, prioridad, fecha_programada)
        SELECT 'Sanidad', a.id_animal, CONCAT('Próxima dosis: ', p_categoria), 
               CONCAT('Aplicación masiva programada de ', COALESCE(p_sub_tipo, 'tratamiento')), 
               'Normal', jc.fecha_prog
        FROM tbl_animal a
        CROSS JOIN JSON_TABLE(p_cronograma_json, '$[*]' COLUMNS(fecha_prog DATE PATH '$')) AS jc
        WHERE a.id_manga_actual = p_id_manga AND a.estado_animal = 'Activo';
    END IF;
    COMMIT;
    
    SELECT JSON_OBJECT(
        'exito', true, 
        'mensaje', CONCAT('Tratamiento masivo registrado a ', v_vacas_afectadas, ' animales.'),
        'animales_vacunados', v_vacas_afectadas,
        'id_registro', v_id_registro
    ) AS resultado;
END$$
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 3. TRIGGER: CIERRE AUTOMÁTICO DE ALERTAS GLOBALES
-- Cuando el operario va al cronograma y marca una vacuna como "Aplicada", 
-- el sistema apaga la campanita de notificaciones global.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TRIGGER trg_sanidad_cierra_alerta
AFTER UPDATE ON tbl_programacion_sanitaria
FOR EACH ROW
BEGIN
    -- Si el estado cambia a 'Aplicado'
    IF OLD.estado != 'Aplicado' AND NEW.estado = 'Aplicado' THEN
        
        -- Buscar todas las alertas globales atadas a este evento y esta fecha, y marcarlas como Atendidas
        UPDATE tbl_alerta a
        JOIN tbl_registro_sanitario_animal rsa ON a.id_animal = rsa.id_animal
        SET a.estado = 'Atendida', a.fecha_atendida = NOW()
        WHERE rsa.id_registro_san = NEW.id_registro_san
          AND a.modulo = 'Sanidad'
          AND DATE(a.fecha_programada) = DATE(NEW.fecha_programada)
          AND a.estado = 'Pendiente';
          
    END IF;
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
-- VISTA: KPIs Reproductivos en Tiempo Real (RF-06)
CREATE OR REPLACE VIEW vw_kpi_reproductivo AS
SELECT 
    (SELECT COUNT(*) FROM tbl_ciclo_reproductivo WHERE estado_ciclo IN ('Preñez Provisional', 'Preñez Confirmada')) AS vacas_prenadas,
    (SELECT COUNT(*) FROM tbl_ciclo_reproductivo WHERE resultado_parto IN ('Exitoso', 'Abortado') 
        AND MONTH(fecha_parto_real) = MONTH(CURDATE()) 
        AND YEAR(fecha_parto_real) = YEAR(CURDATE())) AS partos_del_mes,
    ROUND(
        (SELECT COUNT(*) FROM tbl_ciclo_reproductivo WHERE estado_ciclo = 'Parto Exitoso') 
        / NULLIF((SELECT COUNT(*) FROM tbl_ciclo_reproductivo), 0) * 100
    , 2) AS tasa_exito_pct;
-- VISTA: Próximos Eventos y Alertas
CREATE OR REPLACE VIEW vw_proximos_eventos AS
SELECT 
    ar.id_alerta,
    a.arete,
    ar.tipo_alerta,
    ar.fecha_programada,
    ar.estado_alerta,
    DATEDIFF(ar.fecha_programada, CURDATE()) AS dias_restantes
FROM tbl_alerta_reproductiva ar
JOIN tbl_animal a ON ar.id_animal = a.id_animal
WHERE ar.estado_alerta = 'Pendiente'
ORDER BY ar.fecha_programada ASC;
-- VISTA: Historial Clínico Reproductivo (Resumen de Fases)
CREATE OR REPLACE VIEW vw_historial_reproductivo AS
SELECT 
    cr.id_ciclo,
    a.arete,
    cr.fecha_inicio,
    cr.tipo_evento,
    cr.estado_ciclo,
    cr.fecha_palpacion1,
    cr.resultado_palpacion1,
    cr.fecha_palpacion2,
    cr.resultado_palpacion2,
    cr.fecha_parto_real,
    cr.resultado_parto
FROM tbl_ciclo_reproductivo cr
JOIN tbl_animal a ON cr.id_animal = a.id_animal
ORDER BY cr.fecha_inicio DESC;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                     FIN DEL SCRIPT v3.0 — HOFLOC.SA                     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝