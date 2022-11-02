import xml.etree.ElementTree as ET
#mytree = ET.parse('map.osm')
#myroot = mytree.getroot()

def createClassroomsList():
    mytree = ET.parse('map2.osm')
    myroot = mytree.getroot()
    classroomLevels = {}
    temp = False
    classroom = {}
    for way in myroot.findall('way'):
        for tag in way.findall('tag'):
            if tag.attrib['k'] == 'classroom':
                temp = True
                classroomStr = tag.attrib['v']
                nodesList = []
                for node in way.findall('nd'):
                    node_def = {}
                    for all_node in myroot.findall('node'):
                        if node.attrib['ref'] == all_node.attrib['id']:
                            node_def['lat'] = all_node.attrib['lat']
                            node_def['lon'] = all_node.attrib['lon']
                            nodesList.append(node_def)
                classroom[classroomStr] = nodesList
            #Make sure in josm level comes after classroom number
            if tag.attrib['k'] == 'level' and temp:
                temp = False
                classroomLevels[classroomStr] = tag.attrib['v'] 

    with open('classrooms.txt', 'w') as f:
        for key, val in classroom.items():
            f.write('"' + key + '"' + ": " + "Tuple3(LatLng(" + str(val[0]['lat']) + ", " + str(val[0]['lon']) + "), LatLng(" + str(val[1]['lat']) + ", " + str(val[1]['lon']) + "), " + str(classroomLevels[key]) + "), ")
            f.write('\n')
    return 0

def createPath():
    mytree = ET.parse('map2.osm')
    myroot = mytree.getroot()
    paths = []
    for way in myroot.findall('way'):
        temp = False
        temp2 = False
        isStairs = False
        isIndoor = False
        for tag in way.findall('tag'):
            if tag.attrib['v'] == 'footway':
                temp = True
                isStairs = False
            if tag.attrib['v'] == 'steps':
                temp = True
                isStairs = True
            if temp and tag.attrib['k'] == 'indoor' and tag.attrib['v'] == 'yes' and not isStairs:
                temp2 = True
                isIndoor = True
            if temp:
                if temp2:
                    if tag.attrib['k'] == 'level':
                        path = {}
                        if('.' in tag.attrib['v'] and not (';' in tag.attrib['v'])):
                            path['level'] = tag.attrib['v'].replace('.', '')
                        else:
                            if(tag.attrib['v'] == '0;1'):
                                path['level'] = '10'
                            elif(tag.attrib['v'] == '0;-1'):
                                path['level'] = '-10'
                            elif(tag.attrib['v'] == '2;3'):
                                path['level'] = '23'
                            elif(tag.attrib['v'] == '1;1.5'):
                                path['level'] = '115'                            
                            else:
                                path['level'] = tag.attrib['v']
                else:
                    if isStairs and isIndoor:
                        #999x for stairs
                        path['level'] = 9990
                    elif isStairs:
                        #888x for stairs on ground
                        path['level'] = 8880
                    else:
                        path = {}
                        #-200 represents ground floor
                        path['level'] = "-200"
                line = []
                for node in way.findall('nd'):
                    node_def = {}
                    for all_node in myroot.findall('node'):
                        if node.attrib['ref'] == all_node.attrib['id']:
                            node_def['lat'] = all_node.attrib['lat']
                            node_def['lon'] = all_node.attrib['lon']
                    line.append(node_def)
                path['path'] = line
                paths.append(path)

    with open('paths.txt', 'w') as f:
        for i in paths:
            f.write("Tuple2({" + "'level' : " + i["level"] + "}, {" + "'path' : [")
            f.write('\n')
            for j in i['path']:
                f.write("LatLng(" + j['lat'] + ", " + j['lon'] + "), ")
                f.write('\n')
            f.write("], ")
            f.write('\n')
            f.write("}), ")
            f.write('\n')
    return 0



            
createClassroomsList()
createPath()
