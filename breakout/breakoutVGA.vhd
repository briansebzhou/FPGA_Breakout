process(clkfx)      -- use clkfx from CMT output
    begin
        if rising_edge(clkfx) then
            if (frame = '1') then               -- only update screen positions when frame goes high
                ball_x <= ball_x + ball_dx;     -- update ball x pos
                ball_y <= ball_y + ball_dy;     -- update ball y pos
                
                paddle_x <= paddle_x + paddle_dx;  -- update paddle pos
            end if;
            
            -- display ball, current code shows a square instead of a ball, can update
            if ((hcount >= to_unsigned(ball_x - ball_size,10)) and (hcount <= to_unsigned(ball_x + ball_size, 10)) and
                (vcount >= to_unsigned(ball_y - ball_size,10)) and (vcount <= to_unsigned(ball_y + ball_size, 10))) then
                obj1_red <= b"11";
                obj1_grn <= b"11";
                obj1_blu <= b"11";
            else
                obj1_red <= b"00";
                obj1_grn <= b"00";
                obj1_blu <= b"00";
            end if;
            
            -- display paddle
            if ((hcount >= to_unsigned(paddle_x - paddle_size,10)) and (hcount <= to_unsigned(paddle_x + paddle_size, 10)) and
                (vcount = paddle_y)) then -- different y pos? thicker? either way the paddle y-pos remains constant so we can hard code it
                obj1_red <= b"11";
                obj1_grn <= b"11";
                obj1_blu <= b"11";
            else
                obj1_red <= b"00";
                obj1_grn <= b"00";
                obj1_blu <= b"00";
            end if;
            
            -- display blocks using integer arrays?
            for i in 0 to num_blocks-1 loop
                -- determine which row the block belongs to, specific pixel values will change but regardless they are constants
                if (block_y(i) = b"00") then
                    row_y = 300;
                elsif (block_y(i) = b"01") then
                    row_y = 270;
                elsif (block_y(i) = b"10") then
                    row_y = 240;
                else
                    row_y = 210;
                end if;
                
                if ((hcount >= to_unsigned(block_x(i) - block_size(i),10)) and (hcount <= to_unsigned(block_x(i) + block_size(i), 10)) and
                    (vcount >= to_unsigned(row_y - block_size_y,10)) and (vcount <= to_unsigned(row_y + block_size_y, 10)) and
                    (block_status(i) = '1')) then
                    -- block_size_y is going to be a constant
                    -- block_status indicates whether block has been hit or not
                    obj1_red <= b"11";
                    obj1_grn <= b"11";
                    obj1_blu <= b"11";
                else
                    obj1_red <= b"00";
                    obj1_grn <= b"00";
                    obj1_blu <= b"00";
                end if;
            end loop;
            
            -- btn controlled paddle speed
            if (btn(1) = '1' and btn(0) = '1') then -- no button has priority over another if both are pressed
                paddle_dx <= 0;
            elsif (btn(1) = '1') then
                paddle_dx <= paddle_speed;           -- paddle_speed can be changed later with powerups or just kept constant
            elsif (btn(0) = '1') then
                paddle_dx <= -1 * paddle_speed;
            else
                paddle_dx <= 0;
            end if;
            
            -- ball collision logic: walls
            if (ball_x - ball_size = 0) then
                ball_dx <= 1;
            elsif (ball_x + ball_size = 639) then
                ball_dx <= -1;
            end if;
            
            if (ball_y - ball_size = 0) then
                ball_dy <= 1;
            elsif (ball_y + ball_size = 479) then
                ball_dy <= 0; -- implement game over features here, "press any button to restart"
            end if;
            
            -- ball collision logic: paddle
            if (ball_y + ball_size = paddle_y and
                (ball_x <= paddle_x + paddle_size and ball_x >= paddle_x - paddle_size)) then
                
                ball_dy <= -1;
                if (ball_x > paddle_x) then
                    ball_dx <= 1;
                elsif (ball_x < paddle_x) then
                    ball_dx <= -1;
                end if;
            end if;
            
            -- ball collision logic: blocks
            for i in 0 to num_blocks-1 loop
                if (block_y(i) = b"00") then
                    row_y = 300;
                elsif (block_y(i) = b"01") then
                    row_y = 270;
                elsif (block_y(i) = b"10") then
                    row_y = 240;
                else
                    row_y = 210;
                end if;
                
                if ((ball_x - ball_size = block_x(i) + block_size(i)) and
                    (ball_y <= row_y + block_size_y and ball_y >= row_y - block_size_y) and
                    block_status(i) = '1') then
                    -- if ball hits right side of a block
                    ball_dx <= 1;
                    block_status(i) <= '0';
                elsif ((ball_x + ball_size = block_x(i) - block_size(i)) and
                    (ball_y <= row_y + block_size_y and ball_y >= row_y - block_size_y) and
                    block_status(i) = '1') then
                    -- if ball hits left side of a block
                    ball_dx <= -1;
                    block_status(i) <= '0';
                end if;
                
                if ((ball_y - ball_size_y = row_y + block_size_y) and
                    (ball_x <= block_x(i) + block_size(i) and ball_x >= block_x(i) - block_size(i)) and
                    block_status(i) = '1') then
                    -- if ball hits bottom side of a block
                    ball_dy <= 1;
                    block_status(i) <= '0';
                elsif ((ball_y + ball_size_y = row_y - block_size_y) and
                    (ball_x <= block_x(i) + block_size(i) and ball_x >= block_x(i) - block_size(i)) and
                    block_status(i) = '1') then
                    -- if ball hits top side of a block
                    ball_dy <= -1;
                    block_status(i) <= '0';      
                end if;
            end loop;
        end if;
    end process;
end arch;