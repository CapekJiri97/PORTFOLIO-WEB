/* ========================================================================================
   SPORTS LEAGUE DATABASE - ANALYTICAL QUERIES
   Author: Jiří Čapek
   Description: Collection of SQL queries demonstrating joins, subqueries, 
                set operations, and data manipulation.
========================================================================================
*/

-- --------------------------------------------------------------------------------------
-- 1. BASIC JOINS & SELECTIONS
-- --------------------------------------------------------------------------------------

-- A. Get match details with field capacity (Simple Join)
SELECT 
    m.date AS match_date, 
    f.capacity, 
    f.name AS field_name
FROM match m 
JOIN field f ON m.fid = f.fid;

-- B. Find players who never received a card (Set Difference / EXCEPT)
SELECT pid, name, surname 
FROM player 
EXCEPT 
SELECT pid, name, surname 
FROM player 
JOIN card USING (pid) 
ORDER BY pid;

-- C. Players in teams founded after 1998 (Demonstrating 3 approaches)
-- Method 1: JOIN
SELECT p.name, p.surname, t.name, t.tid 
FROM player p 
JOIN team t ON p.tid = t.tid 
WHERE t.dof > '1998-01-01' 
ORDER BY t.tid;

-- Method 2: Implicit Join (WHERE)
SELECT p.name, p.surname, t.name, t.tid 
FROM player p, team t 
WHERE p.tid = t.tid AND t.dof > '1998-01-01' 
ORDER BY t.tid;

-- Method 3: Set Difference (EXCEPT)
SELECT name, surname, team.name, tid FROM player JOIN team USING (tid)
EXCEPT
SELECT name, surname, team.name, tid FROM player JOIN team USING (tid) WHERE dof < '1998-01-01';


-- --------------------------------------------------------------------------------------
-- 2. ADVANCED JOINS (OUTER, CROSS)
-- --------------------------------------------------------------------------------------

-- A. Players not playing for a specific team (Cross Join & Filtering)
-- Selects all players who do not belong to Team ID 5
SELECT t.name AS team_name, p.name AS player_name, p.surname 
FROM team t 
CROSS JOIN player p 
WHERE t.tid = 5 AND t.tid != p.tid;

-- B. Sponsors and their deals (Left Outer Join)
-- Shows all sponsors, even those without active deals
SELECT s.sid, s.name, d.did, d.amount 
FROM sponsor s 
LEFT OUTER JOIN deal d ON s.sid = d.sid;

-- C. Full Roster Check (Full Outer Join)
-- Shows all players and teams, including players without teams and teams without players
SELECT p.pid, p.name, t.name 
FROM player p 
FULL JOIN team t USING (tid);


-- --------------------------------------------------------------------------------------
-- 3. AGGREGATIONS & COMPLEX FILTERING (GROUP BY, HAVING)
-- --------------------------------------------------------------------------------------

-- A. 'Universal' Viewer (Universal Quantification)
-- Find viewers who bought tickets in ALL existing stores
SELECT * FROM viewer v 
WHERE (
    SELECT COUNT(DISTINCT t.sid) 
    FROM ticket t 
    WHERE t.vid = v.vid
) = (SELECT COUNT(s.sid) FROM store s);

-- B. 'Universal' Sponsor
-- Find sponsors who sponsored ALL teams
SELECT s.name AS sponsor_name, COUNT(DISTINCT t.tid) AS teams_sponsored
FROM sponsor s 
JOIN deal d ON s.sid = d.sid 
JOIN team t ON d.tid = t.tid 
GROUP BY s.sid 
HAVING COUNT(DISTINCT t.tid) = (SELECT COUNT(*) FROM team);

-- C. Teams sorted by their tallest player (Nested Subquery in SELECT)
SELECT t.name, 
       (SELECT MAX(p.height) FROM player p WHERE p.tid = t.tid) AS max_player_height 
FROM team t 
ORDER BY max_player_height;

-- D. Player Performance Summary (Complex Aggregation - Query 'K')
-- Lists players with at least 3 matches played, sorted by match count
SELECT 
    p.name, 
    p.surname, 
    t.name AS team_name, 
    COUNT(DISTINCT part.mid) AS match_count 
FROM player p 
JOIN participation part USING(pid) 
JOIN team t USING(tid) 
GROUP BY p.pid, t.tid, p.name, p.surname, t.name 
HAVING COUNT(DISTINCT part.mid) >= 3 
ORDER BY match_count DESC;


-- --------------------------------------------------------------------------------------
-- 4. SET OPERATIONS & EXISTENCE CHECKS
-- --------------------------------------------------------------------------------------

-- A. Inactive Players (NOT EXISTS)
SELECT * FROM player p 
WHERE NOT EXISTS (
    SELECT 1 FROM participation r WHERE p.pid = r.pid
);

-- B. Premium Matches (UNION)
-- Matches in large stadiums (>50k) OR with experienced referees (>6 years)
SELECT m.mid, m.date, m.time, f.name AS venue_info, 'Large Stadium' as type 
FROM match m JOIN field f ON m.fid = f.fid WHERE f.capacity > 50000
UNION
SELECT m.mid, m.date, m.time, r.name AS venue_info, 'Experienced Ref' as type 
FROM match m JOIN referee r ON m.rid = r.rid WHERE r.exp > 6;

-- C. Sponsored & Experienced Teams (INTERSECT)
-- Teams that have sponsors AND have players with 5+ matches
SELECT t.tid, t.name AS team_name FROM team t 
WHERE t.tid IN (SELECT DISTINCT tid FROM deal)
INTERSECT
SELECT t.tid, t.name AS team_name FROM team t
JOIN (
    SELECT tid FROM participation p 
    JOIN player pl USING(pid) 
    GROUP BY tid 
    HAVING COUNT(DISTINCT p.mid) >= 5
) AS exp_teams ON t.tid = exp_teams.tid 
ORDER BY tid;


-- --------------------------------------------------------------------------------------
-- 5. VIEWS & DATA MANIPULATION (DML)
-- --------------------------------------------------------------------------------------

-- A. Create View for Player-Team details
CREATE VIEW PlayerTeamView AS 
SELECT p.name, p.surname, t.name AS team_name 
FROM player p 
JOIN team t ON p.tid = t.tid;

-- Query the View
SELECT * FROM PlayerTeamView WHERE name = 'Jiří';

-- B. Insert with Subquery
-- Clone a referee's stats to a new assistant
INSERT INTO referee (name, surname, exp, type) 
SELECT 'Lucas', 'Johnson', exp, 'Assistant Referee' 
FROM referee 
WHERE name = 'John' AND surname = 'Doe';

-- C. Conditional Update
-- Update 'spec' attribute for experienced players (5+ matches)
UPDATE player 
SET spec = 'Zkušenost' 
WHERE pid IN (
    SELECT pid FROM participation 
    GROUP BY pid HAVING COUNT(*) >= 5
);

-- D. Cleanup (Delete)
-- Remove players who never participated in a match
DELETE FROM player 
WHERE pid NOT IN (SELECT DISTINCT pid FROM participation);

-- Rollback (Safety first!)
ROLLBACK;