local messages = {"Молоко куплено", "Молоко закончилось", "Проверить молоко"}
while true do
    print(messages[math.random(1, #messages)])
    os.sleep(2)
end
