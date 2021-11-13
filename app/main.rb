$gtk.reset

LCD_X = 330
LCD_Y = 164
LCD_W = 619
LCD_H = 391
LCD_HI = 225
LCD_LO = 10
NUM_FLASHES = 6
MAX_MISSES = 1
AUDIO = true
SOUNDS = true
START_FLICKER_TIME = 20

def tick(args)
  setup(args) unless args.state.state
  flash(args)
  process_input(args)
  calc(args)
end

def setup(args)
  setup_sprites(args)

  static_render(args) if args.state.tick_count
  args.state.state = :begin
  args.state.player.pos = 2
  args.state.flashers = []
  args.state.flash_counter = 0
  args.state.flash_start = 0
  args.state.player.misses = 0
  args.state.landers.cols = [
    Array.new(7, :empty),
    Array.new(6, :empty),
    Array.new(5, :empty)
  ]
  # ticks to wait between advances
  args.state.landers.delay = 12
  args.state.landers.delay_counter = args.state.landers.delay
  args.state.landers.current_col = 0
  args.state.game_timer = 21 * 60
  args.state.game_over = false
  args.state.catch_timer = [0, 0, 0]
  args.state.start_flicker_timer = 0
end

def lcd_on(args, id)
  if id == 'clock'
    args.state.timer_display.a = LCD_HI
  else
    args.state.lcd_sprites.select { |spr| spr[:id] == id }[0].a = LCD_HI
  end
end

def lcd_off(args, id)
  if id == 'clock'
    args.state.timer_display.a = LCD_LO
  else
    args.state.lcd_sprites.select { |spr| spr[:id] == id }[0].a = LCD_LO
  end
end

def flash_lcd(args, flashers)
  args.state.flash_start = args.state.tick_count
  args.state.flashers.concat(flashers)
end

def flash(args)
  return if args.state.flashers.length.zero?

  ticks_passed = args.state.tick_count - args.state.flash_start
  if (ticks_passed % 60).zero?
    args.state.flashers.each { |f| lcd_on(args, f) }
    args.state.flash_counter += 1
    if args.state.flash_counter >= NUM_FLASHES
      args.state.flashers = []
      args.state.flash_counter = 0
    end
  elsif (ticks_passed % 30).zero?
    args.state.flashers.each { |f| lcd_off(args, f) }
  end
end

def setup_sprites(args)
  args.outputs.static_sprites.clear
  args.outputs.static_labels.clear

  args.outputs.static_sprites << {
    x: 0,
    y: 0,
    w: args.grid.w,
    h: args.grid.h,
    path: 'sprites/game-case.png'
  }

  args.state.buttons.left_button_overlay = {
    mouse_in: false,
    x: 112,
    y: 162,
    w: 88,
    h: 88,
    a: 0,
    path: 'sprites/button-round-overlay.png'
  }

  args.state.buttons.right_button_overlay = {
    mouse_in: false,
    x: 1084,
    y: 163,
    w: 88,
    h: 88,
    a: 0,
    path: 'sprites/button-round-overlay.png'
  }

  args.state.buttons.start_button_overlay = {
    mouse_in: false,
    x: 1077,
    y: 609,
    w: 58,
    h: 31,
    a: 0,
    path: 'sprites/button-long-overlay.png'
  }

  args.outputs.static_sprites << args.state.buttons.left_button_overlay
  args.outputs.static_sprites << args.state.buttons.right_button_overlay
  args.outputs.static_sprites << args.state.buttons.start_button_overlay

  # args.state.lcd = %w[win lose miss miss1 miss2 miss3 moon1 moon2 moon3]
  
  # hide two misses
  args.state.lcd = %w[win lose miss miss1 moon1 moon2 moon3]
  args.state.cols = [
    %w[lander1-1 lander1-2 lander1-3 lander1-4 lander1-5 lander1-6 lander1-7],
    %w[lander2-1 lander2-2 lander2-3 lander2-4 lander2-5 lander2-6],
    %w[lander3-1 lander3-2 lander3-3 lander3-4 lander3-5]
  ]

  args.state.lcd.concat(args.state.cols.flatten)
  args.state.lcd_sprites = []
  args.state.lcd_sprites = args.state.lcd.map do |lcd|
    {
      id: lcd,
      x: LCD_X,
      y: LCD_Y,
      w: LCD_W,
      h: LCD_H,
      a: LCD_LO,
      path: "sprites/#{lcd}.png"
    }
  end

  lcd_on(args, 'miss')
end

def static_render(args)
  args.outputs.static_labels << {
    x: 368,
    y: 527,
    text: '88',
    font: 'fonts/DSEG7ClassicMini-Bold.ttf',
    size_enum: 6,
    a: LCD_LO
  }

  args.state.timer_display = {
    x: 368,
    y: 527,
    text: '',
    font: 'fonts/DSEG7ClassicMini-Bold.ttf',
    size_enum: 6,
    a: LCD_HI
  }

  args.outputs.static_labels << args.state.timer_display

  args.state.status_text = {
    x: 368,
    y: 27,
    text: '',
    a: 255,
    r: 255,
    g: 255,
    b: 255,
  }

  args.outputs.static_labels << args.state.status_text
  args.outputs.static_sprites << args.state.lcd_sprites
end

def process_input(args)
  player_move(args, -1) if args.inputs.keyboard.key_down.left
  player_move(args, 1) if args.inputs.keyboard.key_down.right

  setup(args) if args.inputs.keyboard.key_down.space
  miss(args) if args.inputs.keyboard.key_down.one

  if args.inputs.mouse.point.point_inside_circle? [156, 206], 44
    player_move(args, -1) if args.inputs.mouse.click
    args.state.status_text.text = 'Click or use the left arrow key to move left'
    args.state.status_text.x = 425
    if args.inputs.mouse.button_left
      button_mouse_down(args.state.buttons.left_button_overlay)
    else
      args.state.buttons.left_button_overlay[:mouse_in] = true
      button_mouse_within(args, args.state.buttons.left_button_overlay)
    end
  elsif args.state.buttons.left_button_overlay[:mouse_in]
    button_mouse_leave(args, args.state.buttons.left_button_overlay)
    args.state.buttons.left_button_overlay[:mouse_in] = false
  end

  if args.inputs.mouse.point.point_inside_circle? [1138, 206], 44
    args.state.status_text.text = 'Click or use the right arrow key to move right'
    args.state.status_text.x = 420
    player_move(args, 1) if args.inputs.mouse.click
    if args.inputs.mouse.button_left
      button_mouse_down(args.state.buttons.right_button_overlay)
    else
      args.state.buttons.right_button_overlay[:mouse_in] = true
      button_mouse_within(args, args.state.buttons.right_button_overlay)
    end
  elsif args.state.buttons.right_button_overlay[:mouse_in]
    button_mouse_leave(args, args.state.buttons.right_button_overlay)
    args.state.buttons.right_button_overlay[:mouse_in] = false
  end

  if args.inputs.mouse.point.inside_rect? args.state.buttons.start_button_overlay
    args.state.status_text.text = 'Click or press space to start again'
    args.state.status_text.x = 470
    setup(args) if args.inputs.mouse.click
    if args.inputs.mouse.button_left
      button_mouse_down(args.state.buttons.start_button_overlay)
    else
      args.state.buttons.start_button_overlay[:mouse_in] = true
      button_mouse_within(args, args.state.buttons.start_button_overlay)
    end
  elsif args.state.buttons.start_button_overlay[:mouse_in]
    button_mouse_leave(args, args.state.buttons.start_button_overlay)
    args.state.buttons.start_button_overlay[:mouse_in] = false
  end
end

def button_mouse_within(args, button)
  button.a = 40
  button.r = 255
  button.g = 255
  button.b = 255
  args.state.status_text.a = 255
end

def button_mouse_leave(args, button)
  button.a = 0
  args.state.status_text.a = 0
end

def button_mouse_down(button)
  button.a = 40
  button.r = 0
  button.g = 0
  button.b = 0
end

def player_move(args, dir)
  return if args.state.game_over

  # make sure we're not going oob
  next_pos = args.state.player.pos + dir
  return if next_pos < 1 || next_pos > 3

  # change lcd display
  lcd_off(args, "moon#{args.state.player.pos}")
  lcd_on(args, "moon#{next_pos}")

  # record current pos
  args.state.player.pos = next_pos
end

def calc(args)
  case args.state.state
  when :begin
    args.state.start_flicker_timer += 1
    args.state.lcd.each { |l| lcd_on(args, l) }
    args.state.timer_display.text = 88
    if args.state.start_flicker_timer > START_FLICKER_TIME
      args.state.lcd.each { |l| lcd_off(args, l) }
      lcd_on(args, 'miss')
      player_move(args, 0)
      args.state.state = :play
    end
  when :play
    countdown(args)
    update_landers(args)
    check_last_slot(args)
  end
end

def update_landers(args)
  args.state.landers.delay_counter += 1
  # is it time yet?
  args.state.landers.delay_counter = 0 if args.state.landers.delay_counter >= args.state.landers.delay

  return unless args.state.landers.delay_counter.zero?

  (args.state.landers.cols[args.state.landers.current_col].length - 1).downto(0) do |i|
    col = args.state.landers.cols[args.state.landers.current_col]
    slot = col[i]

    case slot
    when :empty
      lcd_off(args, "lander#{args.state.landers.current_col + 1}-#{i + 1}")
      # if row 0 and empty now, maybe spawn lander for next turn
      spawn_lander(args, args.state.landers.current_col) if i.zero?
    when :final
      flash_lcd(args, ["lander#{args.state.landers.current_col + 1}-#{i + 1}"])
      miss(args)
    else
      lcd_on(args, "lander#{args.state.landers.current_col + 1}-#{i + 1}")
      if i < col.length - 1
        col[i + 1] = :full # fill the next slot
        col[i] = :empty
      else # Bogey in the last slot! Quick, catch it!
        col[i] = :final
      end
    end
  end

  args.state.landers.current_col += 1
  args.state.landers.current_col = 0 if args.state.landers.current_col > 2
  args.audio[0] = {
    filename: 'sounds/tick.wav',
    gain: 0.1
  } if AUDIO
  args.outputs.sounds << 'sounds/tick.wav' if SOUNDS
end

def check_last_slot(args)
  3.times do |col_no|
    next unless args.state.landers.cols[col_no][-1] == :final && args.state.player.pos - 1 == col_no

    args.state.catch_timer[col_no] += 1
    next unless args.state.catch_timer[col_no] >= 6

    args.state.landers.cols[col_no][-1] = :empty
    lcd_off(args, "lander#{col_no + 1}-#{args.state.landers.cols[col_no].length}")
    args.state.catch_timer[col_no] = 0
    args.audio[1] = {
      filename: 'sounds/beep.wav',
      gain: 0.1
    } if AUDIO
    args.outputs.sounds << 'sounds/beep.wav' if SOUNDS
  end
end

def spawn_lander(args, col)
  spawn_chance = rand(3)
  args.state.landers.cols[col][0] = :full if spawn_chance.zero?
end

def game_over_win(args)
  args.state.game_over = true
  args.state.state = :win
  flash_lcd(args, %w[win clock])
  args.audio[2] = {
    filename: 'sounds/win.wav',
    gain: 0.1
  } if AUDIO
  args.outputs.sounds << 'sounds/win.wav' if SOUNDS
end

def game_over_lose(args)
  args.state.game_over = true
  args.state.state = :lose
  flash_lcd(args, %w[lose clock])
  args.audio[3] = {
    filename: 'sounds/lose.wav',
    gain: 0.1
  } if AUDIO
  args.outputs.sounds << 'sounds/lose.wav' if SOUNDS
end

def countdown(args)
  return if (args.state.game_timer / 60).to_i <= 0

  args.state.game_timer -= 1
  time_left = (args.state.game_timer / 60).to_i.to_s
  time_left = '0' + time_left if time_left.length < 2
  args.state.timer_display.text = time_left
  game_over_win(args) if time_left == '00'
end

def miss(args)
  return unless args.state.state == :play

  args.state.player.misses += 1
  args.state.player.misses.times do |m|
    lcd_on(args, "miss#{m + 1}")
    flash_lcd(args, ["miss#{m + 1}"])
  end
  if args.state.player.misses >= MAX_MISSES
    game_over_lose(args)
  else
    args.audio[4] = {
      filename: 'sounds/lose.wav',
      gain: 0.1
    } if AUDIO
    args.outputs.sounds << 'sounds/miss.wav' if SOUNDS
  end
end
