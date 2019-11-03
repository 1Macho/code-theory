redundancy = 1
message = "The cake is a lie - Keine besonderen Ereignisse."
probability = 10

function toBits(num,bits)
    -- returns a table of bits, most significant first.
    bits = bits or math.max(1, select(2, math.frexp(num)))
    local t = {} -- will contain the bits
    for b = bits, 1, -1 do
        t[b] = math.fmod(num, 2)
        num = math.floor((num - t[b]) / 2)
    end
    return t
end

function create_data(origin, target, data, target_function)
  local new_data = {}
  new_data.update = true
  new_data.target = {x=target.x,y=target.y}
  new_data.data = data
  new_data.altered = false
  new_data.target_function = target_function
  new_data.origin = {x=origin.x,y=origin.y}
  new_data.position = {x=origin.x,y=origin.y}
  new_data.interpolation = 0
  return new_data
end

function data_update(data,dt)
  if not data.update then
    return
  end
  data.interpolation = data.interpolation + ((dt * ((3*data.interpolation - 1.5) * (3*data.interpolation - 1.5)+2)))/4
  data.position.x = ((data.target.x - data.origin.x) * data.interpolation) + data.origin.x
  data.position.y = ((data.target.y - data.origin.y) * data.interpolation) + data.origin.y
  if (data.interpolation >= 1) then
    data.target_function(data)
  end
end

function list_add(list, object)
  list[#list + 1] = object
end

height = 120
area = 700
start_p = 30
mid_p = start_p + area / 2
end_p = start_p + area


datas = {}

message_queue = {}
message_queue_position = 1

send_text = ""
recv_text = ""
send_decoder = {}
send_decoder.buffer = {}
recv_decoder = {}
recv_decoder.buffer = {}



decode = function(decoder, data)
  list_add(decoder.buffer,data)
  if (#decoder.buffer == 8 * redundancy) then
    local accum = 0
    for i=1,8,1 do
      internal = 0
      for j=0,redundancy-1,1 do
        internal = internal + decoder.buffer[(i-1)*redundancy + j + 1]
      end
      if internal > redundancy / 2 then
        internal = 1
      else
        internal = 0
      end
      accum = accum + (math.pow(2,8-(i)) * internal)
    end
    decoder.buffer = {}
    if (accum < 32 or accum > 128) then
      return "*"
    end
    result = ""
    if pcall(function () result = string.char(accum) end) then
      return result
    else
      return "*"
    end
  end
  return
end

encode = function (message)
  for i=1,#message,1 do
    number = string.byte(message:sub(i,i))
    bits = toBits(number, 8)
    for j=1,#bits,1 do
      for i=1,redundancy,1 do
        list_add(message_queue, bits[j])
      end
    end
  end
end

receiver = function (data)
  data.update = false
  char_dec = decode(recv_decoder, data.data)
  if char_dec then
    recv_text = recv_text .. char_dec
  end
end

noise_generator = function (data)
  if (math.random(0,100) < probability) then
    data.data = math.random(0,1)
    data.altered = true
  end
  data.origin.x = mid_p
  data.origin.y = height
  data.target.x = end_p
  data.target.y = height
  data.target_function = receiver
  data.interpolation = 0
end

sender = function ()
  if (#message_queue+1 > message_queue_position) then
    local origin = {}
    local target = {}
    origin.x = start_p
    origin.y = height
    target.x = mid_p
    target.y = height
    char_dec = decode(send_decoder, message_queue[message_queue_position])
    if char_dec then
      send_text = send_text .. char_dec
    end
    local data = create_data(origin, target, message_queue[message_queue_position], noise_generator)
    message_queue_position = message_queue_position + 1
    list_add(datas, data)
  end
end

function love.load()
  math.randomseed( os.time() )
  love.graphics.setFont(love.graphics.newFont(18))
  encode(message)
end

counter = 0

function love.update(dt)
  if counter >= 0.1 then
    counter = 0
    sender()
  end
  counter = counter + dt
  for k,v in pairs(datas) do
    data_update(v,dt)
  end
end

function love.draw()
  love.graphics.clear(0.05,0.05,0.05)
  love.graphics.setColor(1, 1, 0)
  love.graphics.line(mid_p, height - 20, mid_p, height + 40)
  for k,v in pairs(datas) do
    if v.update then
      love.graphics.setColor(0,1,0)
      if v.altered then
        love.graphics.setColor(1,0,0)
      end
      love.graphics.print("" .. v.data, v.position.x, v.position.y)
    end
  end
  love.graphics.setColor(1,1,1)
  love.graphics.print("Send:" .. send_text, 20, 20)
  love.graphics.print("Recv:" .. recv_text, 20, 40)
end
