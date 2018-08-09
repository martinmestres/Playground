--        Markov's Playground
-- --------------------------------
-- Page 1 & 2:
--  Enc 1: Change Page
--  Key 1 Alternative Controls
--
-- Page 1: 
--  Alt + Key 2 randomize SCALE
--  Alt + Key 3 randomize PROBABILITIES
--  Enc 2: Change Anchor Position
--  Enc 3: Change note generation Probability
--  Alt + Enc 2: Change Selected Note
--  Alt + Enc 3: Change "reset to anchor" counter
--
-- Page 2: 
--  Key 2 PLAY selected LOOP
--  Key 3 Record LOOP *
--  Enc 2: LOOP Shift
--  Enc 3: Select Loop to PLAY
--  Alt + Enc 1: Selected LOOP length
--  Alt + Key 2: Select REC 1
--  Alt + Key 3: Select REC 2


engine.name = "PolyPerc"

local loopLength = {8,8}        -- Loops Length {8,8} ???
local Scale = {0,2,4,5,7,9,11}
local Prob = {{},{},{},{},{},{},{}}
local Loop1 = {{".",".",".",".",".",".",".",".",".",".",".",".",".",".",".","."},
               {".",".",".",".",".",".",".",".",".",".",".",".",".",".",".","."}}
local loopPos = {0,0}
local writeLoop = 0
local playLoop = 0
local newNote = 1
local noteSel = 1   
local loopSel = 1
local loopRecSel = 1
local pageNumber = 1
local noteOnProb = 90
local alternate = {{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}}
local restCounter = 0
local anchor = 1
local blink = 0
local rollResult
local loopStateMemory = 0
local altControls = 0
local setRestCounter = 2


params:add_number("bpm",40,200,100)
params:add_number("root note",30,90,60)
params:add_number("lock Lengths",0,1,0)




function init()
  math.randomseed( os.time() )
  engine.cutoff(4000)
  params:add_control("cutoff",controlspec.new(60,10000,'exp',2,4000,'hz'))
  params:set_action("cutoff", function(x) engine.cutoff(x) end)
  engine.amp(1)
  engine.pw(0.5)
  rndProb()
  counter = metro.alloc(count, 0.15, -1)
  counter:start()
  refreshScreen = metro.alloc(refresh, 0.11, -1)
  refreshScreen:start()
end

-- FPS
function refresh()
  blinker()
  redraw()
end
  

-- Counter
function count()
  counter.time = (60 / (params:get("bpm"))) / 4                       --Change Tempo
  if playLoop == 0 then                                               --Check LOOPER OFF state
    rollResult = noteOnRoll()
    if rollResult == 1 then   
      noteSel = probRoll()
      engine.hz(midi_to_hz(params:get("root note") + noteSel))        --Play note
      restCounter = 0                                                 --Rester Counter
    else actRestCounter()
    end
  looper()
  else 
    rollResult = noteOnRoll()
    looper()
    if tonumber(Loop1[loopSel][loopPos[loopSel]]) ~= nil then  -- Check LOOPER ON state
      engine.hz(midi_to_hz(params:get("root note") + Loop1[loopSel][loopPos[loopSel]]))
      if loopSel == loopRecSel then
        for i=1, 7 do
          if Loop1[loopSel][loopPos[loopSel]] == Scale[i] then         
            newNote = i
            break 
          end
        end
      else noteSel = probRoll()   
      end
    end
  end  
redraw()
end

-- LOOPER 
function looper()
  for i= 1, 2 do
    loopPos[i] = util.clamp(((loopPos[i] + 1) % (loopLength[i]+1)), 1, loopLength[i])
    if params:get("lock Lengths") == 1 then                     -- Lock Loops Position in locked lengths MODE
      loopPos[2] = loopPos[1] 
    end
  end
  if writeLoop == 1 then
    if rollResult == 0 then
      Loop1[loopRecSel][loopPos[loopSel]] = "."   
    else
      Loop1[loopRecSel][loopPos[loopSel]] = noteSel
    end  
  end
end

-- Random Scale Generator
function rndScale()
  Scale[1] = 0
  for i=2, 7 do
    Scale[i] = Scale[i-1] + math.random(1,3)       -- Creates Scale{}
  end
end


-- Random Prob Gen per note     --REVOIR SYSTEME D'ALEATOIRE
function rndProb()              --FAIRE DE LA FONCTION LE MELANGE DUNE TABLE
  for i=1, 7 do                 --METTRE CA EN CAS DE LONG PRESS DANS KEY3
    remain = 100
    deck = shuffleTable{1,2,3,4,5,6,7}                              -- random distribution order 
    for i=1, math.random(0, 10) do deck = shuffleTable(deck) end    -- even more deck shuffle
    for j=1, 7 do                                
      Prob[i][deck[j]] = util.clamp((math.random(0, remain)), 0, 90) -- Mixup tables + prevent 100%
      remain = (remain - Prob[i][deck[j]]) 
    end
  end
end


-- Note On roll
function noteOnRoll()
  local Test = math.random(100)
  if Test >= noteOnProb then return 0
  else return 1
  end
end


-- Midi to Hz
function midi_to_hz(note)
  local hz = (440 / 32) * (2 ^ ((note - 9) / 12))
  return hz
end


-- Prob roll
function probRoll()
  
  currentNote = 1
  repeat
  local Test = math.random(100) 
    if Test >= Prob[newNote][currentNote] then
      currentNote = currentNote+1
      if currentNote > 7 then currentNote = 1 end
      x = false
    else x = true end
  until x == true
  newNote = currentNote
  if restCounter >= setRestCounter then  --check Restcounter and reset
  newNote = anchor end                      --Anchor HERE
  return Scale[newNote] 
end


-- shuffle table content
function shuffleTable(t)                 
  for i = #t, 2, -1 do
    local swap = math.random(1, i)
    t[i], t[swap] = t[swap], t[i]
    return t
  end
end

-- Rest Counter
function actRestCounter()
  restCounter = restCounter + 1 
end

--Blinker
function blinker()
  if blink == 0 then blink = 4
  elseif blink == 4 then blink = 15
  elseif blink == 15 then blink = 0 end
  return blink
end

-- FPS
function fps()
end



-- BUTTONS
function key(n, z) 
  -- KEY1 activate alternative controls
  if writeLoop == 0 then --Prevent write/Alt conflicts
  if n == 1 and z == 1 then altControls = 1 
  elseif n == 1 and z == 0 then altControls = 0
  end
  end
-------------KEYPAGE1----------------------------------------------------  
  if pageNumber == 1 then     
    if altControls == 1 then -- ALT CONTROLS
      -- PAGE 1 Key2 change Scale 
      if n == 2 and z == 1 then             
      rndScale() end
      -- PAGE 1 Key 3 chang Probs
      if n == 3 and z == 1 then
      rndProb() 
      end
    end
-------------KEYPAGE2----------------------------------------------------
  else 
    if altControls == 1 then -- ALT CONTROLS
      -- Loop REC Selector
      if n == 2 and z == 1 then loopRecSel = 1
      elseif n == 3 and z == 1 then loopRecSel = 2
      end
    else                     -- BASE CONTROLS
      if n == 2 and z == 1 then  -- LOOP SWITCH ON/OF
        playLoop = (playLoop + 1) % 2
        loopStateMemory = 1 
        writeLoop = 0
        if playLoop == 0 then loopStateMemory = 0 end
      end    
      if n == 3 and z == 1 then
        if loopSel == loopRecSel then playLoop = 0 end
        writeLoop = 1
      else 
        writeLoop = 0
        if loopStateMemory == 1 then playLoop = 1 end
      end
    end
  end
-------------END----------------------------------------------------  
  redraw()
end 


--ENCODERS
function enc(n, d)
  --Page change
  if altControls == 0 and n == 1 then
    pageNumber = util.clamp((pageNumber + d),1,2)                         
  end  
-------------ENCPAGE1----------------------------------------------------
  if pageNumber == 1 then
    if altControls == 1 then  -- ALT CONTROLS
      -- Note selected note MANUAL change
      if n == 2 then
        Scale[anchor] =  util.clamp(Scale[anchor] + d, 0, 24) 
      end
      if n == 3 then
        setRestCounter = util.clamp((setRestCounter + d),1, 8)
        redraw()
        end
    end
    if altControls == 0 then  -- BASIC CONTROLS
      -- Anchor SELECTOR
      if n == 2 then              
        anchor = util.clamp((anchor + d),1,7)
        redraw()
      end
      -- Note On Prob
      if n == 3 then
        noteOnProb = util.clamp((noteOnProb + d), 1, 100)
        redraw()
      end
    end  
  end
-------------ENCPAGE2---------------------------------------------------- 
  if pageNumber == 2 then
    -- Loop Selection
    if n == 3 then
      loopSel = util.clamp((loopSel + d), 1, 2) 
    end
    -- Loop Length
    if n == 1 and altControls == 1 then
      loopLength[loopSel] = util.clamp((loopLength[loopSel] + d), 1, 16)
      if params:get("lock Lengths") == 1 then                               -- LOCK LENTGH PARAM
        if loopSel == 1 then
          loopLength[2] = loopLength[1]
        elseif loopSel == 2 then
          loopLength[1] = loopLength[2]
        end
      end
      redraw()
    end
    --Table SHIFT
    if n == 2 then
      --RIGHT
      if d-1 == 0 then
      local memory = Loop1[loopSel][loopLength[loopSel]]
      table.remove(Loop1[loopSel], loopLength[loopSel])
      table.insert(Loop1[loopSel],1,memory)
      --LEFT
      else
      local memory = Loop1[loopSel][1]
      table.remove(Loop1[loopSel], 1)
      table.insert(Loop1[loopSel],loopLength[loopSel],memory)
      end
    end
  end
end



function redraw()
  screen.clear()
--------------------------------------------------------PAGE1----------------------------------------------------  
  if pageNumber == 1 then
    screen.aa(0)
    screen.font_size(8)
    -- Draws Notes  
    for i=1, 7 do                                   
      screen.move((12*i)+4, 6)
      if i == anchor then             --Anchor blink Feedback
        screen.level(blink)      
      else screen.level(15) 
      end
      screen.font_face(1)
      screen.text_center(Scale[i])
      -- Draws probability for each note    
      for j=1, 7 do                                 
        screen.move((12*i)+4, 10 + (j*7))
        screen.level(1)
        screen.text_center(Prob[i][j])
      end
    end
    -- Line  
    screen.move(12, 9)
    screen.line(93, 9)
    screen.level(3)
    screen.stroke()
    screen.move(105, 0)
    screen.line(105, 64)
    screen.level(15)
    screen.stroke()    
    -- Curent note Feedback
    screen.rect((newNote*12-1)+4,8,4,1)           
    screen.level(5)
    screen.stroke()
    -- NoteOne Probability
    screen.move(118, 55)
    screen.level(15)
    screen.text_center(noteOnProb .. "%")
    -- RestResetSet
    screen.move(118, 64)
    screen.level(2)
    if setRestCounter > 1 then
      screen.text_center(setRestCounter .. "rests")
    else screen.text_center(setRestCounter .. "rest")
    end
    
--------------------------------------------------------PAGE2---------------------------------------------------- 
  else 
    -- Line  
    screen.level(2 - loopSel)       -- Loop 1 selection FeedBack
    screen.rect(0, 30, 128, 4)                             
    screen.fill()
    screen.level(-1 + loopSel)      -- Loop 2 selection FeedBack
    screen.rect(0, 45, 128, 4)                              
    screen.fill()
  -- Looper Memory feedback 
    for ii=1, 2 do
      for i=1, loopLength[ii] do
        screen.move(((127/loopLength[ii])*i)-4, ((15+(ii*15)) - alternate[ii][i]))
        -- Jumping numbers feedback
        if loopSel == ii then
          if playLoop == 1 then
            if tonumber(Loop1[ii][i]) ~= nil then                       
              alternate[ii][i] = (alternate[ii][i] + 1) % math.random(2, 4) 
            end
          else alternate[ii] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0} 
          end
        else alternate[ii] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}  
        end
        -- Looper current position feedback
        if i == loopPos[ii] then 
          screen.level(15)
        else 
          screen.level(4)
          screen.font_size(8)
          screen.font_face(1)
        end
        screen.text_center(Loop1[ii][i])
      end
    end
    -- Looper On/oFF Feedback rect
    screen.move(11, 9)                       
    if playLoop == 1 then               --Loop On Blink
      screen.rect(115, 58, 6, 6) 
      screen.level(blink)
      screen.fill()
    elseif loopStateMemory == 1 then    --Loop On, Write On Steady State
      screen.rect(115, 58, 6, 6) 
      screen.level(15)
      screen.fill()
    end
    if playLoop == 0 and loopStateMemory == 0 then    --Loop Off, Write Off
      screen.rect(116, 59, 5, 5)
      screen.level(1)
      screen.stroke()
    end
    -- Write On/oFF Feedback 
    if loopRecSel == 1 then
      screen.move(80, 64)
    else
      screen.move(95, 64)
    end
    if writeLoop == 1 then screen.level(blink)
    else screen.level(1)
    end 
    screen.font_size(8)
    screen.font_face(1)
    screen.text("REC".. loopRecSel) 
  end
-----------------------------------------------------ALL-----------------------------------------
  --Curent page
  screen.move(118, 6)
  screen.level(8)
  screen.font_size(8)
  screen.text_center("P" .. pageNumber)
  if altControls == 1 then                          --ALT Feedback
    screen.move(0, 64)
    screen.level(blink+10)
    screen.font_size(7)
    screen.text("ALT")
  end
  screen.update()
end

    