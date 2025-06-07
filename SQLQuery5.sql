SELECT TOP (1000) [id_producto]
      ,[desc_producto]
      ,[Agrupador_Producto]
      ,[Capacidad]
      ,[Medidas]
      ,[Es_lata]
      ,[Capacidad_cm3]
  FROM [Intermedia].[dbo].[int_productos]


-- CTE de precios con rango de vigencia
WITH PreciosConRango AS (
    SELECT 
        PRODUCT_ID,
        DATE AS [FROM],
        LEAD(DATE) OVER (PARTITION BY PRODUCT_ID ORDER BY DATE) AS [UNTIL],
        PRICE
    FROM [starying].[dbo].[starying_Price_Mysql]
),

-- Total facturado por venta
CTE_Total_Facturado AS (
    SELECT 
        v.billing_id, 
        v.date, 
        v.product_id,
        SUM(v.quantity) * p.PRICE AS total_facturado
    FROM [starying].[dbo].[sty_ventas_historicas] v
    LEFT JOIN PreciosConRango p 
        ON v.product_id = p.PRODUCT_ID
        AND v.date >= p.[FROM]
        AND (v.date < p.[UNTIL] OR p.[UNTIL] IS NULL)
    GROUP BY v.billing_id, v.date, v.product_id, p.PRICE
),

-- Descuentos aplicables
CTE_Descuentos AS (
    SELECT 
        f.billing_id,
        f.date,
        f.product_id,
        f.total_facturado,
        ISNULL(MAX(d.PERCENTAGE / 100.0), 0.0) AS descuento
    FROM CTE_Total_Facturado f
    LEFT JOIN [starying].[dbo].[stayin discount My Sql] d
        ON f.date >= d.[FROM]
        AND (f.date < d.[UNTIL] OR d.[UNTIL] IS NULL)
        AND f.total_facturado > d.TOTAL_BILLING
    GROUP BY f.billing_id, f.date, f.product_id, f.total_facturado
)

-- Consulta final con cantidades, litros, descuentos, etc.
SELECT 
    v.*,
    p.PRICE,
    v.quantity * p.PRICE AS total_facturado,
    v.quantity * p.PRICE * (1 - d.descuento) AS total_facturado_con_descuento,
    d.descuento,
    CASE WHEN pr.Es_lata = 1 THEN v.quantity ELSE 0 END AS Cantidad_Latas,
    CASE 
        WHEN pr.Medidas = 'Liter' THEN pr.Capacidad * v.quantity
        ELSE (pr.Capacidad_cm3 / 1000.0) * v.quantity 
    END AS Cantidad_Litros_Vendidos
FROM [starying].[dbo].[sty_ventas_historicas] v
LEFT JOIN PreciosConRango p 
    ON v.product_id = p.PRODUCT_ID
    AND v.date >= p.[FROM]
    AND (v.date < p.[UNTIL] OR p.[UNTIL] IS NULL)
LEFT JOIN CTE_Descuentos d 
    ON v.billing_id = d.billing_id AND v.product_id = d.product_id
LEFT JOIN [Intermedia].[dbo].[int_productos] pr 
    ON v.product_id = pr.id_producto
