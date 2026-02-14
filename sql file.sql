-- ============================================
-- CS621 Spatial Databases Project
-- Title: Belfast Street Art & Murals Analysis
-- Student Schema: p260073
-- Studen number: 25252247
-- ============================================

-- ============================================
-- SECTION 1: TABLE CREATION
-- ============================================

-- Table: belfast_artworks (imported from GeoJSON via QGIS)
-- Contains 247 artworks including murals, sculptures, memorials, etc.

-- Add category column for cleaner classification
ALTER TABLE p260073.belfast_artworks ADD COLUMN category VARCHAR(50);

UPDATE p260073.belfast_artworks
SET category = CASE
    WHEN artwork_type = 'mural' THEN 'Mural'
    WHEN artwork_type = 'graffiti' THEN 'Street Art'
    WHEN artwork_type = 'sculpture' THEN 'Sculpture'
    WHEN artwork_type = 'statue' THEN 'Statue'
    WHEN artwork_type = 'installation' THEN 'Installation'
    WHEN artwork_type = 'stained_glass' THEN 'Stained Glass'
    WHEN historic = 'memorial' THEN 'Memorial'
    WHEN tourism = 'artwork' THEN 'Artwork'
    ELSE 'Other'
END;

-- ============================================
-- SECTION 2: DATA EXPLORATION QUERIES
-- ============================================

-- Query: Count total artworks
SELECT COUNT(*) AS total_artworks FROM p260073.belfast_artworks;

-- Query: Count artworks by type
SELECT artwork_type, COUNT(*) AS count
FROM p260073.belfast_artworks
GROUP BY artwork_type
ORDER BY count DESC;

-- Query: Count artworks by category
SELECT category, COUNT(*) AS count
FROM p260073.belfast_artworks
GROUP BY category
ORDER BY count DESC;

-- ============================================
-- SECTION 3: SPATIAL ANALYSIS QUERIES
-- ============================================

-- Query 1: Find the geographic center of all Belfast artworks
SELECT ST_AsText(ST_Centroid(ST_Collect(wkb_geometry))) AS center_point
FROM p260073.belfast_artworks;

-- Query 2: Count artworks within 1km of Belfast city centre
SELECT category, COUNT(*) AS count
FROM p260073.belfast_artworks
WHERE ST_DWithin(
    wkb_geometry::geography,
    ST_SetSRID(ST_MakePoint(-5.929594, 54.598251), 4326)::geography,
    1000  -- 1000 meters = 1km
)
GROUP BY category
ORDER BY count DESC;

-- Query 3: Find the 10 most isolated artworks (furthest from other artworks)
SELECT a.name, a.category,
       ROUND(MIN(ST_Distance(a.wkb_geometry::geography, b.wkb_geometry::geography))::numeric, 2) AS nearest_artwork_meters
FROM p260073.belfast_artworks a
JOIN p260073.belfast_artworks b ON a.ogc_fid != b.ogc_fid
WHERE a.name IS NOT NULL
GROUP BY a.ogc_fid, a.name, a.category
ORDER BY nearest_artwork_meters DESC
LIMIT 10;

-- ============================================
-- SECTION 4: BUFFER ANALYSIS
-- ============================================

-- Query 4: Create 500m buffer zones around all murals
DROP TABLE IF EXISTS p260073.mural_buffers;

CREATE TABLE p260073.mural_buffers AS
SELECT 
    ogc_fid,
    name,
    category,
    ST_Buffer(wkb_geometry::geography, 500)::geometry AS buffer_geom
FROM p260073.belfast_artworks
WHERE category = 'Mural';

-- Query 5: Calculate mural coverage area
SELECT 
    COUNT(*) AS number_of_murals,
    ROUND(CAST(SUM(ST_Area(buffer_geom::geography, true)) AS numeric) / 1000000, 2) AS total_buffer_area_km2,
    ROUND(CAST(ST_Area(ST_Union(buffer_geom)::geography, true) AS numeric) / 1000000, 2) AS actual_coverage_km2
FROM p260073.mural_buffers;

-- ============================================
-- SECTION 5: KEY FINDINGS
-- ============================================

-- Finding 1: Belfast has 247 artworks total, with 53 murals
-- Finding 2: 105 artworks (43%) are within 1km of city centre
-- Finding 3: Murals are heavily clustered - 53 mural buffers would cover 41km² 
--            but actual coverage is only 9km² due to overlap
-- Finding 4: Most isolated artwork is "The Seahorse" sculpture (1.4km from nearest artwork)
-- Finding 5: City centre has highest concentration of murals and street art

-- ============================================
-- END OF PROJECT SQL FILE
-- ============================================
