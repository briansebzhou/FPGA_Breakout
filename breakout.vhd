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
        obj1_blu:  out std_logic_vector(1 downto 0)
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
    constant BALL_SPEED_X: integer := 1;
    constant BALL_SPEED_Y: integer := 1;
    
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
    


    signal paddle_x: integer range GAME_LEFT_BOUND to GAME_RIGHT_BOUND := (GAME_LEFT_BOUND + GAME_RIGHT_BOUND) / 2;
    
    signal ball_x: integer range GAME_LEFT_BOUND to GAME_RIGHT_BOUND := (GAME_LEFT_BOUND + GAME_RIGHT_BOUND) / 2;
    signal ball_y: integer range GAME_TOP_BOUND to GAME_BOTTOM_BOUND := PADDLE_Y - BALL_SIZE - 1;
    signal ball_dx: integer range -2 to 2 := BALL_SPEED_X;
    signal ball_dy: integer range -2 to 2 := -BALL_SPEED_Y;
    
    type block_array is array (0 to (BLOCKS_PER_ROW * NUM_ROWS - 1)) of std_logic;
    signal blocks: block_array := (others => '1');
    
    signal game_over: std_logic := '0';
    signal game_started: std_logic := '0';
    signal score: integer range 0 to 40 := 0;

    -- Helper function for collision detection
    function is_colliding(
        x1, y1, w1, h1: integer;  -- First object
        x2, y2, w2, h2: integer   -- Second object
    ) return boolean is
    begin
        return not (
            x1 + w1 < x2 or 
            x1 > x2 + w2 or 
            y1 + h1 < y2 or 
            y1 > y2 + h2    
        );
    end function;

begin
    process(clkfx)
        variable block_x, block_y: integer;
        variable next_ball_x : integer range GAME_LEFT_BOUND to GAME_RIGHT_BOUND;
        variable next_ball_y : integer range GAME_TOP_BOUND to GAME_BOTTOM_BOUND;
    begin
        if rising_edge(clkfx) then
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
                    -- Color based on row
                    case (i / BLOCKS_PER_ROW) is
                        when 0 => obj1_red <= "11"; -- Red row
                        when 1 => obj1_grn <= "11"; -- Green row
                        when 2 => obj1_blu <= "11"; -- Blue row
                        when others => 
                            obj1_red <= "11";      -- White row
                            obj1_grn <= "11";
                            obj1_blu <= "11";
                    end case;
                end if;
            end loop;
            
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
            
            -- Game state update on frame
            if frame = '1' then
                -- Game restart logic
                if game_over = '1' and (btn(0) = '1' or btn(1) = '1') then
                    game_over <= '0';
                    game_started <= '0';
                    blocks <= (others => '1');
                    score <= 0;
                    ball_x <= paddle_x;
                    ball_y <= PADDLE_Y - BALL_SIZE - 1;
                end if;
                
                if game_over = '0' then
                    -- Paddle movement with boundary checking
                    if btn(1) = '1' and paddle_x < GAME_RIGHT_BOUND - PADDLE_WIDTH/2 - 1 then
                        paddle_x <= paddle_x + PADDLE_SPEED;
                    elsif btn(0) = '1' and paddle_x > GAME_LEFT_BOUND + PADDLE_WIDTH/2 + 1 then
                        paddle_x <= paddle_x - PADDLE_SPEED;
                    end if;
                    
                    -- Game start logic
                    if game_started = '0' then
                        ball_x <= paddle_x;
                        ball_y <= PADDLE_Y - BALL_SIZE - 1;
                        
                        if btn(0) = '1' or btn(1) = '1' then
                            game_started <= '1';
                            ball_dx <= -1;
                            ball_dy <= -BALL_SPEED_Y;
                        end if;
                    end if;
                    
                    -- Ball movement and collision logic
                    if game_started = '1' then
                        next_ball_x := ball_x + ball_dx;
                        next_ball_y := ball_y + ball_dy;
                        
                        -- Horizontal boundary checking
                        if next_ball_x - BALL_SIZE <= GAME_LEFT_BOUND then
                            next_ball_x := GAME_LEFT_BOUND + BALL_SIZE;
                            ball_dx <= abs(ball_dx);
                        elsif next_ball_x + BALL_SIZE >= GAME_RIGHT_BOUND then
                            next_ball_x := GAME_RIGHT_BOUND - BALL_SIZE;
                            ball_dx <= -abs(ball_dx);
                        end if;
                        
                        -- Vertical boundary checking
                        if next_ball_y - BALL_SIZE <= GAME_TOP_BOUND then
                            next_ball_y := GAME_TOP_BOUND + BALL_SIZE;
                            ball_dy <= abs(ball_dy);
                        elsif next_ball_y + BALL_SIZE >= GAME_BOTTOM_BOUND then
                            next_ball_y := GAME_BOTTOM_BOUND - BALL_SIZE;
                            game_over <= '1';
                        end if;
                        
                        -- Update ball position
                        ball_x <= next_ball_x;
                        ball_y <= next_ball_y;
                        
                        -- Ball collision with paddle
                        if is_colliding(
                            ball_x - BALL_SIZE, ball_y - BALL_SIZE, BALL_SIZE*2, BALL_SIZE*2,
                            paddle_x - PADDLE_WIDTH/2, PADDLE_Y, PADDLE_WIDTH, PADDLE_HEIGHT
                        ) then
                            ball_dy <= -abs(ball_dy);
                            
                            -- Adjust ball angle based on paddle hit location
                            if ball_x < paddle_x - PADDLE_WIDTH/4 then
                                ball_dx <= -abs(ball_dx);
                            elsif ball_x > paddle_x + PADDLE_WIDTH/4 then
                                ball_dx <= abs(ball_dx);
                            end if;
                        end if;
                        
                        -- Ball collision with blocks
                        for i in 0 to (BLOCKS_PER_ROW * NUM_ROWS - 1) loop
                            if blocks(i) = '1' then
                                block_x := BLOCKS_START_X + (i mod BLOCKS_PER_ROW) * (BLOCK_WIDTH + 10);
                                block_y := BLOCKS_START_Y + (i / BLOCKS_PER_ROW) * (BLOCK_HEIGHT + 10);
                                
                                if is_colliding(
                                    ball_x - BALL_SIZE, ball_y - BALL_SIZE, BALL_SIZE*2, BALL_SIZE*2,
                                    block_x, block_y, BLOCK_WIDTH, BLOCK_HEIGHT
                                ) then
                                    blocks(i) <= '0';
                                    ball_dy <= -ball_dy;
                                    score <= score + 1;
                                end if;
                            end if;
                        end loop;
                    end if;
                end if;
            end if;
        end if;
    end process;
end arch;