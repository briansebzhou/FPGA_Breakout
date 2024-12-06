library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity breakout is
    port(
        clkfx:     in  std_logic;
        hcount:    in  unsigned(9 downto 0);
        vcount:    in  unsigned(9 downto 0);
        frame:     in  std_logic;
        btn:       in  std_logic_vector(1 downto 0);
        obj1_red:  out std_logic_vector(1 downto 0);
        obj1_grn:  out std_logic_vector(1 downto 0);
        obj1_blu:  out std_logic_vector(1 downto 0);
        score:     out integer range 0 to 40;
        game_started_port: out std_logic;
        game_over_port:    out std_logic;
        victory_port:      out std_logic
    );
end breakout;

architecture arch of breakout is
    -- Constants
    constant SCREEN_WIDTH:  integer := 640;
    constant SCREEN_HEIGHT: integer := 480;
    
    constant MARGIN: integer := 50;
    
    constant GAME_WIDTH:  integer := SCREEN_WIDTH - 2 * MARGIN;
    constant GAME_HEIGHT: integer := SCREEN_HEIGHT - 2 * MARGIN;
    
    constant GAME_LEFT_BOUND: integer := MARGIN + 10;
    constant GAME_RIGHT_BOUND: integer := SCREEN_WIDTH - MARGIN - 10;
    constant GAME_TOP_BOUND: integer := MARGIN + 10;
    constant GAME_BOTTOM_BOUND: integer := SCREEN_HEIGHT - MARGIN - 10;

    constant PADDLE_WIDTH: integer := 80;
    constant PADDLE_HEIGHT: integer := 10;
    constant PADDLE_SPEED: integer := 5;
    constant PADDLE_Y: integer := GAME_BOTTOM_BOUND - PADDLE_HEIGHT - 10;
    
    constant BALL_SIZE: integer := 8;
    constant BALL_SPEED_INIT:   integer := 2;
    constant BALL_SPEED_MIN:    integer := 1;
    constant BALL_SPEED_MAX:    integer := 4;
    
    constant BLOCK_WIDTH: integer := 40;
    constant BLOCK_HEIGHT: integer := 15;
    constant BLOCKS_PER_ROW: integer := 10;
    constant NUM_ROWS: integer := 4;
    
    -- Calculate block grid total width and height
    constant BLOCK_GRID_WIDTH: integer := BLOCKS_PER_ROW * (BLOCK_WIDTH + 10) - 10;
    constant BLOCK_GRID_HEIGHT: integer := NUM_ROWS * (BLOCK_HEIGHT + 10) - 10;
    
    -- Calculate starting positions to center the block grid in the game area
    constant BLOCKS_START_X: integer := MARGIN + 10 + (GAME_WIDTH - 20 - BLOCK_GRID_WIDTH) / 2;
    constant BLOCKS_START_Y: integer := MARGIN + 10 + (GAME_HEIGHT - 20 - BLOCK_GRID_HEIGHT) / 2 - 40;
    
    type game_state_type is (START_STATE, PLAY_STATE, GAME_OVER_STATE);
    signal game_state: game_state_type := START_STATE;

    signal game_over: std_logic := '0';
    signal game_started: std_logic := '0';
    signal victory: std_logic := '0';
    signal score_i: integer range 0 to 40 := 0;

    signal paddle_x: integer range GAME_LEFT_BOUND to GAME_RIGHT_BOUND := (GAME_LEFT_BOUND + GAME_RIGHT_BOUND) / 2;
    
    signal ball_x: integer range GAME_LEFT_BOUND to GAME_RIGHT_BOUND := (GAME_LEFT_BOUND + GAME_RIGHT_BOUND) / 2;
    signal ball_y: integer range GAME_TOP_BOUND to GAME_BOTTOM_BOUND := PADDLE_Y - BALL_SIZE - 1;
    signal ball_dx: integer range -BALL_SPEED_MAX to BALL_SPEED_MAX := BALL_SPEED_INIT;
    signal ball_dy: integer range -BALL_SPEED_MAX to BALL_SPEED_MAX := -BALL_SPEED_INIT;
    
    signal random_cnt_x: integer := 75;
    signal random_cnt_y: integer := 75;
    signal random_blk_x: integer := 300;
    signal random_blk_y: integer := 75;
    signal random_blk: std_logic := '1';
    
    type block_array is array (0 to (BLOCKS_PER_ROW * NUM_ROWS - 1)) of std_logic;
    signal blocks: block_array := (others => '1');

    -- Add these after the existing type declarations
    type block_color is (RED, CYAN, GREEN, WHITE);
    type block_color_array is array (0 to (BLOCKS_PER_ROW * NUM_ROWS - 1)) of block_color;
    signal block_colors: block_color_array;

    -- Modify the random seed signal to be updated in the process
    signal random_seed: std_logic_vector(15 downto 0) := x"ABCD";

    -- Modify the function signature to include random_seed as an input
    function init_random_colors(seed: std_logic_vector(15 downto 0)) return block_color_array is
        variable colors: block_color_array;
        variable current_seed: std_logic_vector(15 downto 0);
        variable rand_value: integer range 0 to 3;
    begin
        current_seed := seed;

        for i in colors'range loop
            -- Perform LFSR transformation
            current_seed := current_seed(14 downto 0) & 
                            (current_seed(15) xor current_seed(14) xor 
                             current_seed(12) xor current_seed(3));
            
            -- Use the lowest 2 bits to generate color
            rand_value := to_integer(unsigned(current_seed(1 downto 0)));
            
            case rand_value is
                when 0 => colors(i) := RED;
                when 1 => colors(i) := CYAN;
                when 2 => colors(i) := GREEN;
                when 3 => colors(i) := WHITE;
                when others => colors(i) := WHITE;
            end case;
        end loop;

        return colors;
    end function;

    -- Types for collision detection
    type collision_side is (NONE, LEFT, RIGHT, TOP, BOTTOM, CORNER);
    type collision_info is record
        collided: std_logic;
        side: collision_side;
    end record;

    -- Improved collision detection function
    function detect_collision(
        ball_x, ball_y: integer;  -- Ball center position
        ball_size: integer;       -- Ball size (radius)
        obj_x, obj_y: integer;    -- Object position (top-left corner)
        obj_width, obj_height: integer  -- Object dimensions
    ) return collision_info is
        variable result: collision_info;
        variable ball_left: integer;
        variable ball_right: integer;
        variable ball_top: integer;
        variable ball_bottom: integer;
        variable obj_right: integer;
        variable obj_bottom: integer;
        variable closest_x: integer;
        variable closest_y: integer;
        variable dist_squared: integer;
    begin
        -- Initialize result
        result.collided := '0';
        result.side := NONE;
        
        -- Calculate ball bounds
        ball_left := ball_x - ball_size;
        ball_right := ball_x + ball_size;
        ball_top := ball_y - ball_size;
        ball_bottom := ball_y + ball_size;
        
        -- Calculate object bounds
        obj_right := obj_x + obj_width;
        obj_bottom := obj_y + obj_height;
        
        -- First check if there's any overlap
        if not (ball_right < obj_x or ball_left > obj_right or
                ball_bottom < obj_y or ball_top > obj_bottom) then
            
            -- Find the closest point on the object to the ball center
            if ball_x < obj_x then
                closest_x := obj_x;
            elsif ball_x > obj_right then
                closest_x := obj_right;
            else
                closest_x := ball_x;
            end if;
            
            if ball_y < obj_y then
                closest_y := obj_y;
            elsif ball_y > obj_bottom then
                closest_y := obj_bottom;
            else
                closest_y := ball_y;
            end if;
            
            -- Calculate distance squared
            dist_squared := (ball_x - closest_x) * (ball_x - closest_x) + 
                          (ball_y - closest_y) * (ball_y - closest_y);
            
            -- If the distance between the closest point and ball center is less than ball_size,
            -- we have a collision
            if dist_squared <= ball_size * ball_size then
                result.collided := '1';
                
                -- Determine collision side based on the closest point
                if closest_y = obj_bottom then
                    result.side := BOTTOM;
                elsif closest_y = obj_y then
                    result.side := TOP;
                elsif closest_x = obj_x then
                    result.side := LEFT;
                elsif closest_x = obj_right then
                    result.side := RIGHT;
                else
                    result.side := CORNER;
                end if;
            end if;
        end if;
        return result;
    end function;

begin
    score <= score_i;
    game_started_port <= game_started;
    game_over_port <= game_over;
    victory_port <= victory;

    process(clkfx)
        variable block_x, block_y: integer;
        variable next_ball_x : integer range GAME_LEFT_BOUND to GAME_RIGHT_BOUND;
        variable next_ball_y : integer range GAME_TOP_BOUND to GAME_BOTTOM_BOUND;
        variable next_ball_dx : integer range -BALL_SPEED_MAX to BALL_SPEED_MAX;
        variable next_ball_dy : integer range -BALL_SPEED_MAX to BALL_SPEED_MAX;
        variable cleared_blocks_count : integer range 0 to (BLOCKS_PER_ROW * NUM_ROWS) := 0;
        -- Add collision detection variables here
        variable collision: collision_info;
        variable ball_x_change,ball_y_change: std_logic;
    begin
        if rising_edge(clkfx) then
            if random_cnt_x >= 525 then
                random_cnt_x <= 75;
            else
                random_cnt_x <= random_cnt_x + 1;
            end if;
            
            if random_cnt_y >= 130 then
                random_cnt_y <= 75;
            else
                random_cnt_y <= random_cnt_y + 1;
            end if;         
            
            -- LFSR transformation
            random_seed <= random_seed(14 downto 0) & 
                           (random_seed(15) xor random_seed(14) xor 
                            random_seed(12) xor random_seed(3));
            
            -- Reset game logic (redundant with new game_state FSM
     --       if game_over = '1' and (btn(0) = '1' or btn(1) = '1') then
     --           blocks <= (others => '1');
     --           block_colors <= init_random_colors(random_seed);  -- Initialize random colors
     --           cleared_blocks_count := 0;
     --       end if;

            -- Default colors (black background)
            obj1_red <= "00";
            obj1_grn <= "00";
            obj1_blu <= "00";
            
            -- Draw precise rectangular border
            if ((hcount >= to_unsigned(GAME_LEFT_BOUND - 10, 10) and 
                 hcount < to_unsigned(GAME_LEFT_BOUND, 10) and 
                 vcount >= to_unsigned(GAME_TOP_BOUND - 10, 10) and 
                 vcount < to_unsigned(GAME_BOTTOM_BOUND + 10, 10)) or
                (hcount >= to_unsigned(GAME_RIGHT_BOUND, 10) and 
                 hcount < to_unsigned(GAME_RIGHT_BOUND + 10, 10) and 
                 vcount >= to_unsigned(GAME_TOP_BOUND - 10, 10) and 
                 vcount < to_unsigned(GAME_BOTTOM_BOUND + 10, 10)) or
                (vcount >= to_unsigned(GAME_TOP_BOUND - 10, 10) and 
                 vcount < to_unsigned(GAME_TOP_BOUND, 10) and 
                 hcount >= to_unsigned(GAME_LEFT_BOUND - 10, 10) and 
                 hcount < to_unsigned(GAME_RIGHT_BOUND + 10, 10)) or
                (vcount >= to_unsigned(GAME_BOTTOM_BOUND, 10) and 
                 vcount < to_unsigned(GAME_BOTTOM_BOUND + 10, 10) and 
                 hcount >= to_unsigned(GAME_LEFT_BOUND - 10, 10) and 
                 hcount < to_unsigned(GAME_RIGHT_BOUND + 10, 10))) then
                obj1_red <= "11";
                obj1_grn <= "11";
                obj1_blu <= "11";
            end if;
            
            -- Draw blocks
            for i in 0 to (BLOCKS_PER_ROW * NUM_ROWS - 1) loop
                block_x := BLOCKS_START_X + (i mod BLOCKS_PER_ROW) * (BLOCK_WIDTH + 10);
                block_y := BLOCKS_START_Y + (i / BLOCKS_PER_ROW) * (BLOCK_HEIGHT + 10);
                
                if blocks(i) = '1' and
                   hcount >= to_unsigned(block_x, 10) and
                   hcount < to_unsigned(block_x + BLOCK_WIDTH, 10) and
                   vcount >= to_unsigned(block_y, 10) and
                   vcount < to_unsigned(block_y + BLOCK_HEIGHT, 10) then
                    -- gray blocks when start or game over
                    if (game_started = '0') or (game_over = '1') then
                        obj1_red <= "10";
                        obj1_grn <= "10";
                        obj1_blu <= "10";
                    else
                        -- Color based on block_colors array
                        case block_colors(i) is
                            when RED => 
                                obj1_red <= "11";
                                obj1_grn <= "00";
                                obj1_blu <= "00";
                            when CYAN =>
                                obj1_red <= "00";
                                obj1_grn <= "11";
                                obj1_blu <= "11";
                            when GREEN =>
                                obj1_red <= "00";
                                obj1_grn <= "11";
                                obj1_blu <= "00";
                            when WHITE =>
                                obj1_red <= "11";
                                obj1_grn <= "11";
                                obj1_blu <= "11";
                        end case;
                    end if;
                end if;
            end loop;
            
            -- Draw random block
            if random_blk = '1' and
                hcount >= to_unsigned(random_blk_x, 10) and
                hcount < to_unsigned(random_blk_x + BLOCK_WIDTH, 10) and
                vcount >= to_unsigned(random_blk_y, 10) and
                vcount < to_unsigned(random_blk_y + BLOCK_HEIGHT, 10) then
                    obj1_grn <= "11";
            end if;
            
            -- Draw paddle
            if hcount >= to_unsigned(paddle_x - PADDLE_WIDTH/2, 10) and
               hcount < to_unsigned(paddle_x + PADDLE_WIDTH/2, 10) and
               vcount >= to_unsigned(PADDLE_Y, 10) and
               vcount < to_unsigned(PADDLE_Y + PADDLE_HEIGHT, 10) then
                obj1_red <= "11";
                obj1_grn <= "11";
                obj1_blu <= "11";
            end if;
            
            -- Draw ball with circular approach
            if ((hcount >= to_unsigned(ball_x - BALL_SIZE, 10)) and 
                (hcount < to_unsigned(ball_x + BALL_SIZE, 10)) and 
                (vcount >= to_unsigned(ball_y - BALL_SIZE, 10)) and 
                (vcount < to_unsigned(ball_y + BALL_SIZE, 10))) then
                
                if ((abs(to_integer(hcount) - ball_x) * abs(to_integer(hcount) - ball_x) + 
                     abs(to_integer(vcount) - ball_y) * abs(to_integer(vcount) - ball_y)) 
                    <= BALL_SIZE * BALL_SIZE) then
                    
                    if ((abs(to_integer(hcount) - ball_x) * abs(to_integer(hcount) - ball_x) + 
                         abs(to_integer(vcount) - ball_y) * abs(to_integer(vcount) - ball_y)) 
                        <= (BALL_SIZE-2) * (BALL_SIZE-2)) then
                        obj1_red <= "11";
                        obj1_grn <= "11";
                        obj1_blu <= "11";
                    else
                        obj1_red <= "10";
                        obj1_grn <= "10";
                        obj1_blu <= "10";
                    end if;
                end if;
            end if;
            
            if frame = '1' then
                case game_state is
                    when START_STATE =>
                        game_started <= '0';
                        victory <= '0';
                        ball_x <= paddle_x;
                        ball_y <= PADDLE_Y - BALL_SIZE - 1;
                        blocks <= (others => '1');
                        random_blk <= '1';
                        block_colors <= init_random_colors(random_seed);  -- Initialize random colors
                        score_i <= 0;
                        if btn(0) = '1' or btn(1) = '1' then
                            -- game_started <= '1';
                            game_state <= PLAY_STATE;
                            ball_dy <= -BALL_SPEED_INIT;
                            if btn(0) = '1' then -- initial ball direction depends on button pressed
                                ball_dx <= -BALL_SPEED_INIT;
                            else
                                ball_dx <= BALL_SPEED_INIT;
                            end if;
                        end if;



                    when PLAY_STATE =>
                        game_started <= '1';
                        game_over <= '0';
                        random_blk <= '1';

                        -- Paddle movement with boundary checking
                        if btn(1) = '1' and btn(0) = '1' then
                            paddle_x <= paddle_x;
                        elsif btn(1) = '1' and paddle_x < GAME_RIGHT_BOUND - PADDLE_WIDTH/2 - 1 then
                            paddle_x <= paddle_x + PADDLE_SPEED;
                        elsif btn(0) = '1' and paddle_x > GAME_LEFT_BOUND + PADDLE_WIDTH/2 + 1 then
                            paddle_x <= paddle_x - PADDLE_SPEED;
                        end if;

                        -- Predict next ball position
                        next_ball_x := ball_x + ball_dx;
                        next_ball_y := ball_y + ball_dy;
                        next_ball_dx := ball_dx;
                        next_ball_dy := ball_dy;
                        
                        -- Ball collision with paddle
                        collision := detect_collision(
                            next_ball_x, next_ball_y, BALL_SIZE,
                            paddle_x - PADDLE_WIDTH/2, PADDLE_Y,
                            PADDLE_WIDTH, PADDLE_HEIGHT
                        );
                        
                        if collision.collided = '1' then
                            -- Modify ball speed based on paddle movement
                            if (btn(1) = '1') and (paddle_x < GAME_RIGHT_BOUND - PADDLE_WIDTH/2 - 1) and (ball_dx + 1 <= BALL_SPEED_MAX) then
                                next_ball_dx := ball_dx + 1;
                            elsif (btn(0) = '1') and (paddle_x > GAME_LEFT_BOUND + PADDLE_WIDTH/2 + 1) and (ball_dx - 1 >= -BALL_SPEED_MAX) then
                                next_ball_dx := ball_dx - 1;
                            end if;
                            
                            -- Reverse vertical direction and apply modified horizontal speed
                            next_ball_dy := -abs(ball_dy);
                            next_ball_dx := next_ball_dx;
                        end if;
                        
                        -- Ball collision with blocks
                        ball_x_change := '0';
                        ball_y_change := '0';
                        for i in 0 to (BLOCKS_PER_ROW * NUM_ROWS - 1) loop
                            -- move block check up here to use in if statement
                            block_x := BLOCKS_START_X + (i mod BLOCKS_PER_ROW) * (BLOCK_WIDTH + 10);
                            block_y := BLOCKS_START_Y + (i / BLOCKS_PER_ROW) * (BLOCK_HEIGHT + 10);
                            if blocks(i) = '1' 
                                and ((next_ball_x - BALL_SIZE - BLOCK_WIDTH - 10 < block_x) or (next_ball_x + BALL_SIZE + 10 > block_x))
                                and ((next_ball_y - BALL_SIZE - BLOCK_HEIGHT - 10 < block_y) or (next_ball_y + BALL_SIZE + 10 > block_y))
                                then
                                --block_x := BLOCKS_START_X + (i mod BLOCKS_PER_ROW) * (BLOCK_WIDTH + 10);
                                --block_y := BLOCKS_START_Y + (i / BLOCKS_PER_ROW) * (BLOCK_HEIGHT + 10);
                                
                                collision := detect_collision(
                                    next_ball_x, next_ball_y, BALL_SIZE,
                                    block_x, block_y, BLOCK_WIDTH, BLOCK_HEIGHT
                                );
                                
                                if collision.collided = '1' then
                                    blocks(i) <= '0';  -- Destroy block
                                    
                                    -- Speed modifications based on block color
                                    case block_colors(i) is
                                        when RED =>
                                            -- Increase speed magnitude by 1
                                            if next_ball_dx > 0 and next_ball_dx + 1 <= BALL_SPEED_MAX then
                                                next_ball_dx := next_ball_dx + 1;
                                            elsif next_ball_dx < 0 and next_ball_dx - 1 >= -BALL_SPEED_MAX then
                                                next_ball_dx := next_ball_dx - 1;
                                            end if;
                                            
                                            if next_ball_dy > 0 and next_ball_dy + 1 <= BALL_SPEED_MAX then
                                                next_ball_dy := next_ball_dy + 1;
                                            elsif next_ball_dy < 0 and next_ball_dy - 1 >= -BALL_SPEED_MAX then
                                                next_ball_dy := next_ball_dy - 1;
                                            end if;
                                            
                                        when CYAN =>
                                            -- Decrease speed magnitude by 1
                                            if next_ball_dx > 0 then
                                                next_ball_dx := next_ball_dx - 1;
                                            elsif next_ball_dx < 0 then
                                                next_ball_dx := next_ball_dx + 1;
                                            end if;
                                            
                                            if next_ball_dy > 1 then
                                                next_ball_dy := next_ball_dy - 1;
                                            elsif next_ball_dy < -1 then
                                                next_ball_dy := next_ball_dy + 1;
                                            end if;
                                            
                                        when others =>
                                            null;
                                    end case;

                                    -- Handle collision direction
                                    case collision.side is
                                        when LEFT =>
                                            if ball_x_change = '0' then
                                                next_ball_dx := -abs(next_ball_dx);
                                                ball_x_change := '1';
                                            end if;
                                        when RIGHT =>
                                            if ball_x_change = '0' then
                                                next_ball_dx := abs(next_ball_dx);
                                                ball_x_change := '1';
                                            end if;
                                        when TOP =>
                                            if ball_y_change = '0' then
                                                next_ball_dy := -abs(next_ball_dy);
                                                ball_y_change := '1';
                                            end if;
                                        when BOTTOM =>
                                            if ball_y_change = '0' then
                                                next_ball_dy := abs(next_ball_dy);
                                                ball_y_change := '1';
                                            end if;
                                        when others =>
                                            if ball_y_change = '0' then
                                                next_ball_dy := -(next_ball_dy);
                                                next_ball_dx := -(next_ball_dx);
                                                ball_y_change := '1';
                                            end if;
                                    end case;
                                end if;
                            end if;
                        end loop;
                        ball_x_change := '0';
                        ball_y_change := '0';
                        
                        -- Horizontal boundary checking
                        if next_ball_x - BALL_SIZE <= GAME_LEFT_BOUND then
                            next_ball_x := GAME_LEFT_BOUND + BALL_SIZE;
                            next_ball_dx := abs(next_ball_dx);
                        elsif next_ball_x + BALL_SIZE >= GAME_RIGHT_BOUND then
                            next_ball_x := GAME_RIGHT_BOUND - BALL_SIZE;
                            next_ball_dx := -abs(next_ball_dx);
                        end if;
                        
                        -- Vertical boundary checking
                        if next_ball_y - BALL_SIZE <= GAME_TOP_BOUND then
                            next_ball_y := GAME_TOP_BOUND + BALL_SIZE;
                            next_ball_dy := abs(next_ball_dy);
                        elsif next_ball_y + BALL_SIZE >= GAME_BOTTOM_BOUND then
                            next_ball_y := GAME_BOTTOM_BOUND - BALL_SIZE;
                            game_state <= GAME_OVER_STATE;
                        end if;

                        -- Update ball position and velocity
                        ball_x <= next_ball_x;
                        ball_y <= next_ball_y;
                        ball_dx <= next_ball_dx;
                        ball_dy <= next_ball_dy;

                        -- Random block
                        collision := detect_collision(
                            next_ball_x, next_ball_y, BALL_SIZE,
                            random_blk_x, random_blk_y, BLOCK_WIDTH, BLOCK_HEIGHT
                        );
            
                        if collision.collided = '1' then
                            -- Victory detection
                            if (unsigned(blocks) = 0) then
                                game_state <= GAME_OVER_STATE;
                                random_blk <= '0';            
                                victory <= '1';            
                            end if;
                            random_blk_x <= random_cnt_x;
                            random_blk_y <= random_cnt_y;
                            -- Handle collision direction
                            case collision.side is
                                when LEFT =>
                                    next_ball_dx := -abs(next_ball_dx);
                                when RIGHT =>
                                    next_ball_dx := abs(next_ball_dx);
                                when TOP =>
                                    next_ball_dy := -abs(next_ball_dy);
                                when BOTTOM =>    
                                    next_ball_dy := abs(next_ball_dy);
                                when others =>
                                    if ball_y_change = '0' then
                                        next_ball_dy := -(next_ball_dy);
                                        next_ball_dx := -(next_ball_dx);
                                        ball_y_change := '1';
                                    end if;
                            end case;
                        end if;

                    when GAME_OVER_STATE =>
                        game_started <= '0';
                        game_over <= '1';
                        -- Game restart logic
                        if game_over = '1' and (btn(0) = '1' or btn(1) = '1') then
                            -- game_over <= '0';
                            game_state <= PLAY_STATE;
                            blocks <= (others => '1');
                            block_colors <= init_random_colors(random_seed);  -- Initialize random colors
                            score_i <= 0;
                            ball_x <= paddle_x;
                            ball_y <= PADDLE_Y - BALL_SIZE - 1;
                            ball_dy <= -BALL_SPEED_INIT;
                            if btn(0) = '1' then -- initial ball direction depends on button pressed
                                ball_dx <= -BALL_SPEED_INIT;
                            else
                                ball_dx <= BALL_SPEED_INIT;
                            end if;
                        end if;                       
                end case;
            end if;

            -- Game state update on frame
            -- if frame = '1' then
            --     -- Game restart logic
            --     if game_over = '1' and (btn(0) = '1' or btn(1) = '1') then
            --         game_over <= '0';
            --         blocks <= (others => '1');
            --         block_colors <= init_random_colors(random_seed);  -- Initialize random colors
            --         score_i <= 0;
            --         ball_x <= paddle_x;
            --         ball_y <= PADDLE_Y - BALL_SIZE - 1;
            --         ball_dy <= -BALL_SPEED_INIT;
            --         if btn(0) = '1' then -- initial ball direction depends on button pressed
            --             ball_dx <= -BALL_SPEED_INIT;
            --         else
            --             ball_dx <= BALL_SPEED_INIT;
            --         end if;
            --     end if;
                
            --     if game_over = '0' then
            --         -- Game start logic
            --         if game_started = '0' then
            --             ball_x <= paddle_x;
            --             ball_y <= PADDLE_Y - BALL_SIZE - 1;
            --             blocks <= (others => '1');
            --             block_colors <= init_random_colors(random_seed);  -- Initialize random colors
            --             score_i <= 0;
            --             if btn(0) = '1' or btn(1) = '1' then
            --                 game_started <= '1';
            --                 ball_dy <= -BALL_SPEED_INIT;
            --                 if btn(0) = '1' then -- initial ball direction depends on button pressed
            --                     ball_dx <= -BALL_SPEED_INIT;
            --                 else
            --                     ball_dx <= BALL_SPEED_INIT;
            --                 end if;
            --             end if;
            --         end if;
                    
            --         -- Paddle movement with boundary checking
            --         if btn(1) = '1' and btn(0) = '1' then
            --             paddle_x <= paddle_x;
            --         elsif btn(1) = '1' and paddle_x < GAME_RIGHT_BOUND - PADDLE_WIDTH/2 - 1 then
            --             paddle_x <= paddle_x + PADDLE_SPEED;
            --         elsif btn(0) = '1' and paddle_x > GAME_LEFT_BOUND + PADDLE_WIDTH/2 + 1 then
            --             paddle_x <= paddle_x - PADDLE_SPEED;
            --         end if;
                    
            --         -- Ball movement and collision logic
            --         if game_started = '1' then
            --             next_ball_x := ball_x + ball_dx;
            --             next_ball_y := ball_y + ball_dy;
                        
            --             -- Horizontal boundary checking
            --             if next_ball_x - BALL_SIZE <= GAME_LEFT_BOUND then
            --                 next_ball_x := GAME_LEFT_BOUND + BALL_SIZE;
            --                 ball_dx <= abs(ball_dx);
            --             elsif next_ball_x + BALL_SIZE >= GAME_RIGHT_BOUND then
            --                 next_ball_x := GAME_RIGHT_BOUND - BALL_SIZE;
            --                 ball_dx <= -abs(ball_dx);
            --             end if;
                        
            --             -- Vertical boundary checking
            --             if next_ball_y - BALL_SIZE <= GAME_TOP_BOUND then
            --                 next_ball_y := GAME_TOP_BOUND + BALL_SIZE;
            --                 ball_dy <= abs(ball_dy);
            --             elsif next_ball_y + BALL_SIZE >= GAME_BOTTOM_BOUND then
            --                 next_ball_y := GAME_BOTTOM_BOUND - BALL_SIZE;
            --                 game_over <= '1';
            --             end if;
                        
            --             -- Ball collision with paddle
            --             collision := detect_collision(
            --                 next_ball_x, next_ball_y, BALL_SIZE,
            --                 paddle_x - PADDLE_WIDTH/2, PADDLE_Y,
            --                 PADDLE_WIDTH, PADDLE_HEIGHT
            --             );
                        
            --             if collision.collided = '1' then
            --                 if btn(1) = '1' and paddle_x < GAME_RIGHT_BOUND - PADDLE_WIDTH/2 - 1 then
            --                     ball_dx <= ball_dx + 1;
            --                 elsif btn(0) = '1' and paddle_x > GAME_LEFT_BOUND + PADDLE_WIDTH/2 + 1 then
            --                     ball_dx <= ball_dx - 1;
            --                 else
            --                     ball_dx <= ball_dx;
            --                 end if;
            --                 ball_dy <= -abs(ball_dy);
            --             end if;
                        
            --             -- Ball collision with blocks
            --             for i in 0 to (BLOCKS_PER_ROW * NUM_ROWS - 1) loop
            --                 if blocks(i) = '1' then
            --                     block_x := BLOCKS_START_X + (i mod BLOCKS_PER_ROW) * (BLOCK_WIDTH + 10);
            --                     block_y := BLOCKS_START_Y + (i / BLOCKS_PER_ROW) * (BLOCK_HEIGHT + 10);
                                
            --                     collision := detect_collision(
            --                         next_ball_x, next_ball_y, BALL_SIZE,
            --                         block_x, block_y, BLOCK_WIDTH, BLOCK_HEIGHT
            --                     );
                                
            --                     if collision.collided = '1' then
            --                         blocks(i) <= '0';  -- Destroy block
                                    
            --                         case collision.side is
            --                             when LEFT =>
            --                                 ball_dx <= -abs(ball_dx);
            --                                 -- next_ball_x := block_x - BALL_SIZE;
            --                             when RIGHT =>
            --                                 ball_dx <= abs(ball_dx);
            --                                 -- next_ball_x := block_x + BLOCK_WIDTH + BALL_SIZE;
            --                             when TOP =>
            --                                 ball_dy <= -abs(ball_dy);
            --                                 -- next_ball_y := block_y - BALL_SIZE;
            --                             when BOTTOM =>
            --                                 ball_dy <= abs(ball_dy);
            --                                 -- next_ball_y := block_y + BLOCK_HEIGHT + BALL_SIZE;
            --                             when NONE =>
            --                                 null;
            --                         end case;
            --                     end if;
            --                 end if;
            --             end loop;

            --             -- Update ball position
            --             ball_x <= next_ball_x;
            --             ball_y <= next_ball_y;
            --         end if;
            --     end if;
            -- end if;

            -- Count cleared blocks
            cleared_blocks_count := 0;
            for i in 0 to (BLOCKS_PER_ROW * NUM_ROWS - 1) loop
                if blocks(i) = '0' then
                    cleared_blocks_count := cleared_blocks_count + 1;
                end if;
            end loop;

            -- Update score
            score_i <= cleared_blocks_count;
        end if;
    end process;
end arch;