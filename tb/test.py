def func():
    lst = []
    i = 0
    while True:
        lst += [i]
        i = i + 1
        yield lst

x = func()

print(x)
print(x)
print(x)
print(x)
print(x)
print(x)

# for val in x:
#     print(val)