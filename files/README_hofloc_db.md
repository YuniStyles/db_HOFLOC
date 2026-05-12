# 🐄 HOFLOC.SA — Diseño de Base de Datos

> **Sistema:** Gestión Ganadera HOFLOC.SA · El Archivo Agrario
> **Motor:** MySQL 8.0+ (InnoDB · utf8mb4)
> **Normalización:** 3FN (Tercera Forma Normal)
> **Fecha:** Mayo 2026

---

## 1. Resumen ejecutivo

A partir del análisis de **todos los formularios** presentes en la vista de administrador del repositorio (`Frontend/zona_admin/`), se identificaron **24 tablas** que conforman la base de datos completa del sistema. El diseño aplica el patrón **Class-Table-Inheritance** para que cada tipo de animal (Vaca, Toro, Ternero) tenga su propia tabla con atributos exclusivos, sin perder integridad referencial.

### Objetos generados

| Categoría | Cantidad | Detalle |
|---|---|---|
| **Tablas** | 24 | 4 catálogos, 4 entidades de animal, 16 transaccionales |
| **Vistas** | 2 | `vw_animal_completo`, `vw_inventario_mangas` |
| **Triggers** | 5 | Validan herencia + actualizan estados derivados |
| **Stored Procedures** | 2 | `sp_registrar_animal`, `sp_promover_ternero` |

---

## 2. Mapeo Formulario → Tabla

Cada formulario del sistema fue trazado hasta su tabla destino:

| Formulario (origen) | Archivo HTML | Tablas destino |
|---|---|---|
| Login / acceso | `panel_derecho.html` | `tbl_usuario`, `tbl_rol`, `tbl_bitacora` |
| Crear/Editar Animal | `ganado.php` (modal `formNuevoAnimal`) | `tbl_animal` + `tbl_vaca` / `tbl_toro` / `tbl_ternero` |
| Mangas (crear/mover) | `HTML_Mangas/*` (`formAgregar`, `formMover`) | `tbl_manga`, `tbl_movimiento_manga` |
| Pesaje | `HTML_Pesaje/contenido_pesaje.html` | `tbl_pesaje` |
| Producción de Ordeño | `HTML_Produccion/modal_produccion.html` | `tbl_produccion_leche` |
| Nuevo Registro Sanitario | `HTML_GestionSanitaria/modal_nuevo_registro.html` | `tbl_registro_sanitario`, `tbl_registro_sanitario_animal`, `tbl_mastitis_cuartos`, `tbl_producto_sanitario` |
| Evento Reproductivo (IA / Monta) | `HTML_Reproduccion/modal_registro_evento.html` | `tbl_evento_reproductivo` |
| Mortalidad | `HTML_Mortalidad/nuevo_registro.html` | `tbl_mortalidad` |
| Insumos (compra/venta/producción) | `HTML_Gestion_insumos/gi_modal_*.html` | `tbl_insumo`, `tbl_movimiento_insumo`, `tbl_produccion_concentrado_det` |
| Colaboradores | `js_colab/colaboradores.js` | `tbl_colaborador`, `tbl_rol` |
| Alertas | `Alertas.js` | `tbl_alerta` |

---

## 3. Estrategia clave: Herencia por tipo de animal

El usuario pidió explícitamente: *"que cada tipo de animal tenga su tabla"*. La forma técnicamente correcta de lograr esto **sin redundancia ni anomalías** es el patrón **Class-Table-Inheritance**:

```
                    ┌─────────────────────────────┐
                    │       tbl_animal            │  ← Datos COMUNES
                    │  (arete, raza, manga,       │     (PK = id_animal)
                    │   sexo, fecha_nacimiento,   │
                    │   peso_actual, estado...)   │
                    └──────────────┬──────────────┘
                                   │ 1:1 (relación de herencia)
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
     ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
     │  tbl_vaca    │    │  tbl_toro    │    │ tbl_ternero  │
     │  (partos,    │    │  (semental,  │    │  (madre,     │
     │   lactancia, │    │   montas,    │    │   padre,     │
     │   produc.    │    │   libido,    │    │   destete,   │
     │   leche...)  │    │   reprod...) │    │   corral...) │
     └──────────────┘    └──────────────┘    └──────────────┘
       (solo hembras       (solo machos        (m o h < 12m)
        adultas)            adultos)
```

### Reglas de integridad

1. **Cada animal vive en `tbl_animal` Y en UNA sola de las tres tablas hijas**. Imposible duplicar.
2. La columna `tipo_animal` ENUM('Vaca','Toro','Ternero') en la tabla padre **debe coincidir** con la tabla hija donde existe el registro. Esto se valida con tres triggers `BEFORE INSERT` en cada tabla hija.
3. El `id_animal` es **PK en la padre y PK + FK en la hija** (relación 1:1 estricta).
4. **`ON DELETE CASCADE`** desde padre a hija: si se borra un animal, su fila específica también se elimina.

### Caso especial: promoción de ternero

Cuando un ternero crece y se convierte en vaca o toro, el procedimiento `sp_promover_ternero(id_animal, nuevo_tipo, ...)` ejecuta en una transacción:

1. Borra la fila de `tbl_ternero`
2. Actualiza `tbl_animal.tipo_animal` al nuevo valor
3. Inserta la fila correspondiente en `tbl_vaca` o `tbl_toro`
4. Registra en bitácora

Esto preserva el `id_animal`, su historial de pesaje, sanitario, etc.

---

## 4. Justificación de normalización (3FN)

| Forma | Aplicación en el diseño |
|---|---|
| **1FN** — Valores atómicos | Sin campos multi-valor: razas, mangas y procedencias están en sus propios catálogos. Las fechas se separan de horas cuando tiene sentido (pesaje, sanitaria). |
| **2FN** — Dependencias totales de la PK | Tablas con PK simple en su mayoría. Las pocas tablas de detalle (`tbl_registro_sanitario_animal`, `tbl_produccion_concentrado_det`) tienen PK propia + FKs, y todos sus atributos dependen de esa PK, no de partes de ella. |
| **3FN** — Sin dependencias transitivas | `nombre_raza` no se guarda en `tbl_animal` (solo `id_raza` → FK). `nombre_manga` tampoco. El nombre del producto sanitario no se duplica en cada aplicación. El precio total se calcula (`GENERATED ALWAYS AS`) y no se guarda redundantemente. |
| **BCNF** (extra) | Cada determinante es superclave. Las claves candidatas (`arete`, `email`, `usuario`) están como `UNIQUE`. |

### Decisiones explícitas anti-redundancia

- **Producción de leche**: solo guarda `leche_manana_lt` y `leche_tarde_lt`. El total se calcula con columna virtual `GENERATED ALWAYS AS`.
- **Edad del animal**: NO se guarda. Se calcula con `TIMESTAMPDIFF(MONTH, fecha_nacimiento, CURDATE())` en la vista `vw_animal_completo`.
- **Estado de salud del animal**: vive solo en `tbl_animal.estado_general`. Cada registro sanitario lo modifica vía trigger, no se duplica.
- **Manga actual**: se guarda en `tbl_animal.id_manga_actual` (estado actual) y el histórico va a `tbl_movimiento_manga` (no es redundancia, son hechos distintos).

---

## 5. Tablas del sistema (24)

### 🔐 Seguridad y usuarios (3 tablas)

1. **`tbl_rol`** — Catálogo de roles: SuperAdmin, Administrador, Supervisor, Empleado, Veterinario
2. **`tbl_usuario`** — Cuentas de acceso al panel administrativo
3. **`tbl_colaborador`** — Personal de la finca (puede o no tener cuenta de usuario)

### 📚 Catálogos base (3 tablas)

4. **`tbl_raza`** — Holstein, Jersey, Brahman, Angus, etc.
5. **`tbl_procedencia`** — Nacido en finca / Comprado / Donado
6. **`tbl_manga`** — Lotes/corrales (Lechería, Pre-Parto, Sementales, etc.)

### 🐄 Animales — herencia (4 tablas)

7. **`tbl_animal`** *(padre)* — Datos comunes a todo animal: arete, trazabilidad, raza, manga, sexo, peso, fechas, estado general
8. **`tbl_vaca`** *(hija 1:1)* — Estado productivo, partos, lactancia, propósito (leche/doble), producción promedio
9. **`tbl_toro`** *(hija 1:1)* — Tipo de uso (semental/ceba/levante), montas totales, perímetro escrotal, libido
10. **`tbl_ternero`** *(hija 1:1)* — Número interno, corral, padres, peso al nacimiento, esquema de vacunas

### 📊 Operaciones (8 tablas)

11. **`tbl_movimiento_manga`** — Historial de cambios de manga (unitario o masivo)
12. **`tbl_pesaje`** — Registros de peso con fecha, hora, tipo de alimentación
13. **`tbl_produccion_leche`** — Ordeño diario o semanal (mañana/tarde, leche, concentrado)
14. **`tbl_producto_sanitario`** — Catálogo de vacunas, antibióticos, antiparasitarios
15. **`tbl_registro_sanitario`** — Cabecera del evento sanitario (categoría, fecha, veterinario)
16. **`tbl_registro_sanitario_animal`** — Detalle: qué animales fueron tratados (1:N)
17. **`tbl_mastitis_cuartos`** — Diagnóstico por cuarto mamario (AD/PD/AI/PI) solo vacas
18. **`tbl_evento_reproductivo`** — IA, Monta Natural, Palpación, Celo, Parto, Aborto

### ⚰️ Mortalidad (1 tabla)

19. **`tbl_mortalidad`** — Causa, fecha de muerte, observación (relación 1:1 con animal)

### 📦 Insumos (3 tablas)

20. **`tbl_insumo`** — Concentrado, heno, sal mineral, melaza, etc.
21. **`tbl_movimiento_insumo`** — Compras, ventas, producción, consumo animal
22. **`tbl_produccion_concentrado_det`** — Insumos usados en cada lote de producción

### 🔔 Trazabilidad (2 tablas)

23. **`tbl_alerta`** — Alertas de todos los módulos (palpaciones, vacunas, etc.)
24. **`tbl_bitacora`** — Auditoría completa: quién hizo qué, cuándo, sobre qué tabla

---

## 6. Ejemplo de uso: registrar un nuevo animal

El formulario del admin envía los datos a este procedimiento, que se encarga de insertar en la tabla padre y en la hija correcta de forma atómica.

```sql
-- Caso 1: Registrar una nueva VACA Holstein
CALL sp_registrar_animal(
    p_tipo_animal     => 'Vaca',
    p_arete           => '120',
    p_trazabilidad    => '3187',
    p_sexo            => 'Hembra',
    p_id_raza         => 1,                  -- Holstein
    p_id_manga        => 1,                  -- Lechería
    p_id_procedencia  => 1,                  -- Nacido en finca
    p_fecha_nacimiento => '2024-03-15',
    p_peso_kg         => 480.50,
    p_proposito       => 'Leche',
    p_id_madre        => NULL,
    p_id_padre        => NULL,
    p_id_usuario      => 1,
    p_id_animal_out   => @id
);
SELECT @id AS id_nueva_vaca;
-- Resultado: inserta en tbl_animal Y en tbl_vaca de forma atómica.

-- Caso 2: Registrar un TORO semental
CALL sp_registrar_animal(
    'Toro', '45', '2000', 'Macho', 5,        -- Angus
    5,                                       -- Manga Sementales
    2, '2022-01-10', 720.00,
    'Semental', NULL, NULL, 1, @id);

-- Caso 3: Registrar un TERNERO con genealogía
CALL sp_registrar_animal(
    'Ternero', '214', '3180', 'Macho', 4,    -- Brahman
    8,                                       -- Terneros M
    1, '2025-09-20', 35.00,
    NULL,
    100, 50,                                 -- id_madre, id_padre
    1, @id);
```

---

## 7. Consultas frecuentes (ejemplos)

```sql
-- Listar todas las VACAS en producción con su raza y manga
SELECT a.arete, r.nombre_raza, m.nombre AS manga, v.produccion_promedio_lt
FROM tbl_animal a
JOIN tbl_vaca   v ON a.id_animal = v.id_animal
JOIN tbl_raza   r ON a.id_raza   = r.id_raza
JOIN tbl_manga  m ON a.id_manga_actual = m.id_manga
WHERE v.estado_productivo = 'Producción';

-- Producción total de leche por mes
SELECT DATE_FORMAT(fecha_registro,'%Y-%m') AS mes,
       SUM(total_leche_lt) AS litros_mes
FROM tbl_produccion_leche
GROUP BY mes
ORDER BY mes DESC;

-- Animales con vacunas próximas a vencer
SELECT a.arete, al.tipo, al.fecha_programada, al.prioridad
FROM tbl_alerta al
JOIN tbl_animal a ON al.id_animal = a.id_animal
WHERE al.estado = 'Pendiente'
  AND al.fecha_programada BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY
ORDER BY al.fecha_programada;

-- Genealogía de un ternero (con CTE recursiva)
SELECT t.id_animal AS ternero,
       madre.arete AS arete_madre,
       padre.arete AS arete_padre
FROM tbl_ternero t
LEFT JOIN tbl_animal madre ON t.id_madre = madre.id_animal
LEFT JOIN tbl_animal padre ON t.id_padre = padre.id_animal
WHERE t.id_animal = 214;
```

---

## 8. Índices y rendimiento

Los índices están colocados en columnas que el frontend realmente usa para filtrar (visto en los `.js` de admin):

| Tabla | Índice | Razón (frontend) |
|---|---|---|
| `tbl_animal` | `idx_animal_arete` | Buscador de arete en pesaje, sanitaria, reproducción |
| `tbl_animal` | `idx_animal_tipo`  | Filtro por categoría (Vaca/Toro/Ternero) en `ganado.php` |
| `tbl_animal` | `idx_animal_estado`| Filtro por estado en alertas |
| `tbl_pesaje` | `idx_pesaje_animal_fecha` | Historial de peso por animal |
| `tbl_produccion_leche` | `uq_prod_vaca_fecha` | Evita doble registro mismo día |
| `tbl_alerta` | `idx_alerta_estado`, `idx_alerta_prioridad` | KPIs del módulo de alertas |

---

## 9. Archivos entregados

| Archivo | Contenido |
|---|---|
| `hofloc_db.sql` | Script completo: BD + 24 tablas + 5 triggers + 2 SP + 2 vistas + datos seed |
| `diagrama_ER.md` | Diagrama Entidad-Relación en formato Mermaid (renderizable en GitHub, VS Code, etc.) |
| `README_hofloc_db.md` | Este documento |

### Cómo ejecutar el script

```bash
mysql -u root -p < hofloc_db.sql
# o desde el cliente:
mysql> SOURCE hofloc_db.sql;
```
