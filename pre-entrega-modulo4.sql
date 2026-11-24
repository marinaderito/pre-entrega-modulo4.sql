-- ============================================================================
-- Pre-entrega Módulo 4: Consultas multicapa para análisis de negocio
-- Motor: PostgreSQL
--
-- Esquema real:
--   clientes  (id_cliente, nombre, email, edad)
--   productos (id_producto, nombre, categoria, precio_unitario)
--   ventas    (id_venta, id_cliente, id_producto, cantidad, fecha)
-- Nota: la categoría es una columna de texto de productos (no hay tabla
-- categorias), por eso la consulta 1 agrupa por p.categoria.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- CONSULTA 1: Rentabilidad por categoría
-- Problema de negocio: identificar qué categorías generan volumen e ingresos
-- relevantes, para decidir dónde concentrar stock, promociones y compras.
-- Se descartan las categorías de bajo movimiento que solo agregan ruido al
-- reporte.
-- Umbral definido en 3 unidades vendidas porque separa las categorías con
-- rotación sostenida de las de venta ocasional (ajustar según el volumen real
-- de la tabla).
-- El filtro sobre un resultado agregado (SUM) va en HAVING, no en WHERE.
-- ----------------------------------------------------------------------------
SELECT
    p.categoria                        AS categoria,
    SUM(v.cantidad)                    AS unidades_vendidas,
    SUM(v.cantidad * p.precio_unitario) AS ingreso_total
FROM ventas v
JOIN productos p ON p.id_producto = v.id_producto
GROUP BY p.categoria
HAVING SUM(v.cantidad) > 3
ORDER BY ingreso_total DESC;


-- ----------------------------------------------------------------------------
-- CONSULTA 2: Clientes sin compras
-- Problema de negocio: detectar clientes registrados que nunca compraron, para
-- dirigirles campañas de activación (cupón de primera compra, email de
-- bienvenida) y medir la conversión de registros a ventas.
-- LEFT JOIN conserva todos los clientes; los que no tienen coincidencia en
-- ventas quedan con v.id_venta NULL. COALESCE muestra 0 en lugar de NULL.
-- ----------------------------------------------------------------------------
SELECT
    c.id_cliente,
    c.nombre,
    c.email,
    COALESCE(v.cantidad, 0) AS unidades_compradas
FROM clientes c
LEFT JOIN ventas v ON v.id_cliente = c.id_cliente
WHERE v.id_venta IS NULL
ORDER BY c.nombre;


-- ----------------------------------------------------------------------------
-- CONSULTA 3: Top de compras por cliente
-- Problema de negocio: conocer el producto favorito de cada cliente y cuándo
-- compró por última vez, para personalizar recomendaciones y detectar clientes
-- inactivos que conviene reactivar.
-- Une 3 tablas: clientes (c), ventas (v) y productos (p).
-- El producto más comprado sale de una subconsulta correlacionada en el
-- SELECT: agrupa las ventas del cliente por producto, ordena por COUNT(*)
-- descendente y se queda con el primero (LIMIT 1). El desempate es el
-- producto comprado más recientemente.
-- La última transacción sale con MAX(v.fecha).
-- ----------------------------------------------------------------------------
SELECT
    c.nombre                         AS cliente,
    (
        SELECT p2.nombre
        FROM ventas v2
        JOIN productos p2 ON p2.id_producto = v2.id_producto
        WHERE v2.id_cliente = c.id_cliente
        GROUP BY p2.id_producto, p2.nombre
        ORDER BY COUNT(*) DESC, MAX(v2.fecha) DESC
        LIMIT 1
    )                                AS producto_mas_comprado,
    COUNT(DISTINCT p.id_producto)    AS productos_distintos,
    MAX(v.fecha)                     AS ultima_transaccion
FROM clientes c
JOIN ventas v    ON v.id_cliente  = c.id_cliente
JOIN productos p ON p.id_producto = v.id_producto
GROUP BY c.id_cliente, c.nombre
ORDER BY ultima_transaccion DESC;