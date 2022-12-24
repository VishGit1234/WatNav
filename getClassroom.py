import json


def getClassroomInfo(classroom):
    with open("classrooms.json", "r") as f:
        data = json.load(f)
        return (data[classroom])
    
print(getClassroomInfo("DWE 3522"))