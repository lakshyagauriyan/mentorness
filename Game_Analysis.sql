use game_analysis;

-- Problem Statement - Game Analysis dataset
-- 1) Players play a game divided into 3-levels (L0,L1 and L2)
-- 2) Each level has 3 difficulty levels (Low,Medium,High)
-- 3) At each level,players have to kill the opponents using guns/physical fight
-- 4) Each level has multiple stages at each difficulty level.
-- 5) A player can only play L1 using its system generated L1_code.
-- 6) Only players who have played Level1 can possibly play Level2 
--    using its system generated L2_code.
-- 7) By default a player can play L0.
-- 8) Each player can login to the game using a Dev_ID.
-- 9) Players can earn extra lives at each stage in a level.

alter table player_details alter column L1_Status varchar(30);
alter table player_details alter column L2_Status varchar(30);
alter table player_details alter column P_ID int;
alter table player_details add constraint PK_PlayerDetails primary key(P_ID);
alter table player_details drop myunknowncolumn;

alter table level_details drop myunknowncolumn;
alter table level_details
add start_datetime datetime;
update level_details
set start_datetime = TimeStamp;
alter table level_details
drop column timestamp;
alter table level_details alter column Dev_Id varchar(10);
alter table level_details alter column Difficulty varchar(15);
alter table level_details add constraint PK_leveldetails primary key(P_ID,Dev_id,start_datetime);

-- pd (P_ID,PName,L1_status,L2_Status,L1_code,L2_Code)
-- ld (P_ID,Dev_ID,start_time,stages_crossed,level,difficulty,kill_count,
-- headshots_count,score,lives_earned)


-- Q1) Extract P_ID,Dev_ID,PName and Difficulty_level of all players 
-- at level 0
Select P_ID, Dev_ID, Difficulty
From level_details
Where Level=0;


-- Q2) Find Level1_code wise Avg_Kill_Count where lives_earned is 2 and atleast
--    3 stages are crossed
Select L1_Code L1_code, AVG(Kill_Count) Avg_Kill_Count
From level_details
Join player_details On level_details.P_ID=player_details.P_ID
Where Lives_Earned=2 And Stages_crossed>=3
Group By L1_Code;


-- Q3) Find the total number of stages crossed at each diffuculty level
-- where for Level2 with players use zm_series devices. Arrange the result
-- in decsreasing order of total number of stages crossed.
Select Difficulty, Sum(Stages_crossed) as Total_Stages_Crossed
From level_details
Where Level=2 And Dev_ID Like'%zm%'
Group By Difficulty
Order By Total_Stages_Crossed Desc;


-- Q4) Extract P_ID and the total number of unique dates for those players 
-- who have played games on multiple days.
Select P_ID, Count(Distinct start_datetime) as Unique_Dates
From level_details
Group By P_ID
Having Count(Distinct start_datetime)>1;


-- Q5) Find P_ID and level wise sum of kill_counts where kill_count
-- is greater than avg kill count for the Medium difficulty.
Select P_ID, Level, Sum(Kill_Count) as Total_Kill_Count
From level_details
Where Kill_Count>
(Select Avg(Kill_Count)
From level_details 
Where Difficulty Like 'Medium')
Group By Level, P_ID;


-- Q6)  Find Level and its corresponding Level code wise sum of lives earned 
-- excluding level 0. Arrange in asecending order of level.
Select Level, L1_Code,L2_Code,Sum(Lives_Earned) As Total_Lives_Earned
From level_details
Join player_details
On level_details.P_ID=player_details.P_ID
Where Level<>0
Group By Level, L1_Code, L2_Code
Order By Level Asc;


-- Q7) Find Top 3 score based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well. 
With Ranked_Scores as
(Select *, ROW_NUMBER() Over (Partition By Dev_ID Order By Score Desc) as Rank
From level_details
)
Select Dev_ID, Score, Difficulty
From Ranked_Scores
Where Rank<=3;


-- Q8) Find first_login datetime for each device id
Select Dev_ID, Min(start_datetime) as First_Login
From level_details
Group By Dev_ID;


-- Q9) Find Top 5 score based on each difficulty level and Rank them in 
-- increasing order using Rank. Display dev_id as well.
With Ranked_Scores as
(Select *, Rank() Over (Partition By Difficulty Order By Score Desc) as Rank
From level_details
)
Select Dev_ID, Score, Difficulty
From Ranked_Scores
Where Rank<=5;


-- Q10) Find the device ID that is first logged in(based on start_datetime) 
-- for each player(p_id). Output should contain player id, device id and 
-- first login datetime.
Select P_ID, Dev_ID, Min(start_datetime) as First_Login
From level_details
Group By P_ID, Dev_ID;


-- Q11) For each player and date, how many kill_count played so far by the player. That is, the total number of games played 
-- by the player until that date.
-- a) window function
Select P_ID, start_datetime,
Sum(Kill_Count) Over (Partition By P_ID Order By start_datetime) as kill_count_played_so_far
From level_details;
-- b) without window function
Select P_ID, start_datetime,
    (Select Sum(Kill_Count) From level_details L1 Where L2.P_ID=L1.P_ID and L1.start_datetime<=L2.start_datetime) AS kill_count_played_so_far
From level_details L2
Order By P_ID, start_datetime; 


-- Q12) Find the cumulative sum of an stages crossed over a start_datetime 
-- for each player id but exclude the most recent start_datetime
With excluded_latest_start As (
    Select P_ID, Max(start_datetime) As latest_start_datetime
    From level_details
    Group By P_ID
),
cumulative_sum As (
    Select L.P_ID, L.start_datetime, 
           Sum(Stages_crossed) Over (Partition By L.P_ID Order By L.start_datetime) As stages_crossed
    From level_details L
	Join excluded_latest_start E On L.P_ID = E.P_ID
    Where E.latest_start_datetime Is Null Or L.start_datetime< E.latest_start_datetime
)
Select P_ID, start_datetime, stages_crossed As cumulative_stages_crossed
From cumulative_sum;


-- Q13) Extract top 3 highest sum of score for each device id and the corresponding player_id
With Ranked_Scores as
(Select *, Rank() Over (Partition By Dev_ID Order By Score Desc) as Rank
From level_details
)
Select Dev_ID, Score, P_ID
From Ranked_Scores
Where Rank<=3;


-- Q14) Find players who scored more than 50% of the avg score scored by sum of 
-- scores for each player_id
Select P_ID,Score
From level_details
Group By P_ID, Score
Having Score>(Select Avg(Total_Score) * 0.5 From (Select Sum(Score) as Total_Score from level_details Group By P_ID) as avg_score)
Order By P_ID


-- Q15) Create a stored procedure to find top n headshots_count based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well.
CREATE PROCEDURE GetTopNHeadshotsWithDifficulty
    @n INT
AS
BEGIN
    SELECT dev_id, headshots_count, difficulty,
           ROW_NUMBER() OVER (PARTITION BY dev_id ORDER BY headshots_count DESC) AS rank
    FROM (
        SELECT Dev_ID, Headshots_Count, Difficulty,
               ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY Headshots_Count DESC) AS rnk
        FROM level_details
    ) AS ranked
    WHERE rnk <= @n
END

Exec GetTopNHeadshotsWithDifficulty @n=3