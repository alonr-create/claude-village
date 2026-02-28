import Foundation
import AppKit

/// Minimal HTTP server using POSIX sockets for mobile viewer
class VillageWebServer {
    let port: UInt16 = 8420
    private var serverFd: Int32 = -1
    private var isRunning = false
    private var htmlContent: String = ""

    var localURL: String {
        let ip = getLocalIP()
        return "http://\(ip):\(port)"
    }

    func start() {
        htmlContent = generateHTML()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runServer()
        }
    }

    func stop() {
        isRunning = false
        if serverFd >= 0 { close(serverFd) }
    }

    private func runServer() {
        serverFd = socket(AF_INET, SOCK_STREAM, 0)
        guard serverFd >= 0 else { print("⚠️ socket() failed"); return }

        var yes: Int32 = 1
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverFd, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { print("⚠️ bind() failed: \(errno)"); close(serverFd); return }

        guard listen(serverFd, 10) == 0 else { print("⚠️ listen() failed"); close(serverFd); return }

        isRunning = true
        print("🌐 Web server started at \(localURL)")

        while isRunning {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    accept(serverFd, sockPtr, &clientLen)
                }
            }
            guard clientFd >= 0 else { continue }

            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.handleClient(clientFd)
            }
        }
    }

    private func handleClient(_ fd: Int32) {
        // Read request
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = recv(fd, &buffer, buffer.count, 0)
        guard bytesRead > 0 else { close(fd); return }

        let request = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""

        // Determine response
        let body: String
        let contentType: String
        if request.contains("GET /api/status") {
            body = generateStatusJSON()
            contentType = "application/json"
        } else {
            body = htmlContent
            contentType = "text/html; charset=utf-8"
        }

        // Build HTTP response (no leading spaces!)
        let bodyData = body.data(using: .utf8) ?? Data()
        let header = "HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nContent-Length: \(bodyData.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"

        // Send header
        if let headerData = header.data(using: .utf8) {
            headerData.withUnsafeBytes { ptr in
                _ = send(fd, ptr.baseAddress, headerData.count, 0)
            }
        }
        // Send body
        bodyData.withUnsafeBytes { ptr in
            _ = send(fd, ptr.baseAddress, bodyData.count, 0)
        }

        close(fd)
    }

    private func generateStatusJSON() -> String {
        let scanner = ProjectScanner()
        let statuses = scanner.scanAll()
        let todoProvider = TodoDataProvider()
        let inProgress = todoProvider.inProgressTasks()

        var projectsArr: [String] = []
        for project in ProjectDefinition.all {
            let status = statuses[project.id]
            let json = "{\"id\":\"\(project.id.rawValue)\",\"name\":\"\(esc(project.nameHebrew))\",\"emoji\":\"\(project.emoji)\",\"roofColor\":\"\(colorHex(project.roofColor))\",\"wallColor\":\"\(colorHex(project.wallColor))\",\"fileCount\":\(status?.fileCount ?? 0),\"activeTasks\":\(status?.activeTaskCount ?? 0)}"
            projectsArr.append(json)
        }

        var agentsArr: [String] = []
        for agent in AgentDefinition.all {
            let json = "{\"id\":\"\(agent.id.rawValue)\",\"name\":\"\(esc(agent.nameHebrew))\",\"role\":\"\(esc(agent.role.rawValue))\",\"badgeColor\":\"\(colorHex(agent.badgeColor))\"}"
            agentsArr.append(json)
        }

        var tasksArr: [String] = []
        for (_, task) in inProgress {
            tasksArr.append("{\"content\":\"\(esc(task.content))\",\"status\":\"\(esc(task.activeForm))\"}")
        }

        return "{\"projects\":[\(projectsArr.joined(separator: ","))],\"agents\":[\(agentsArr.joined(separator: ","))],\"tasks\":[\(tasksArr.joined(separator: ","))]}"
    }

    private func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func colorHex(_ color: NSColor) -> String {
        guard let c = color.usingColorSpace(.deviceRGB) else { return "#888" }
        return String(format: "#%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }

    private func getLocalIP() -> String {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return "localhost" }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let iface = ptr {
            let sa = iface.pointee.ifa_addr.pointee
            if sa.sa_family == UInt8(AF_INET) {
                let name = String(cString: iface.pointee.ifa_name)
                if name == "en0" || name == "en1" {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(iface.pointee.ifa_addr, socklen_t(sa.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                    return String(cString: host)
                }
            }
            ptr = iface.pointee.ifa_next
        }
        return "localhost"
    }

    // MARK: - HTML Page

    private func generateHTML() -> String {
// NOTE: No indentation on the string to avoid whitespace issues in the HTML
return """
<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="Claude Village">
<title>Claude Village</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#1a3d1a;font-family:-apple-system,'Arial Hebrew',sans-serif;color:#fff;overflow:hidden;touch-action:none}
#header{position:fixed;top:0;left:0;right:0;background:rgba(0,0,0,.6);backdrop-filter:blur(10px);padding:12px 16px;display:flex;align-items:center;gap:10px;z-index:10;direction:rtl}
#header h1{font-size:18px}
.badge{background:rgba(255,255,255,.15);padding:3px 10px;border-radius:12px;font-size:13px}
canvas{display:block;width:100vw;height:100vh}
#info-panel{position:fixed;bottom:0;left:0;right:0;background:rgba(0,0,0,.75);backdrop-filter:blur(10px);padding:16px;transform:translateY(100%);transition:transform .3s;z-index:10;direction:rtl;border-radius:16px 16px 0 0;max-height:50vh;overflow-y:auto}
#info-panel.open{transform:translateY(0)}
#info-panel h2{font-size:20px;margin-bottom:8px}
.row{display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid rgba(255,255,255,.1);font-size:14px}
.label{color:rgba(255,255,255,.6)}
.close-btn{position:absolute;top:12px;left:12px;background:none;border:none;color:#fff;font-size:24px;cursor:pointer}
</style>
</head>
<body>
<div id="header"><span>🦀</span><h1>Claude Village</h1><span class="badge" id="task-count">⚡ 0</span><span class="badge" id="time-badge">☀️</span></div>
<canvas id="village"></canvas>
<div id="info-panel"><button class="close-btn" onclick="closePanel()">✕</button><div id="panel-content"></div></div>
<script>
const canvas=document.getElementById('village'),ctx=canvas.getContext('2d');
let W,H,scale=1,offsetX=0,offsetY=0,data={projects:[],agents:[],tasks:[]},crabs=[],af=0;
function resize(){W=canvas.width=innerWidth*devicePixelRatio;H=canvas.height=innerHeight*devicePixelRatio;canvas.style.width=innerWidth+'px';canvas.style.height=innerHeight+'px';ctx.scale(devicePixelRatio,devicePixelRatio)}
resize();addEventListener('resize',resize);
const HP={matzpen:{x:-200,y:-100},dekel:{x:-200,y:100},'alon-dev':{x:200,y:-100},aliza:{x:200,y:100},boker:{x:0,y:-220},games:{x:0,y:220}};
const AC={eyal:'#36E',yael:'#E5A',ido:'#3B4',roni:'#F81'};
function initC(){const ids=['eyal','yael','ido','roni'],h=Object.values(HP);crabs=ids.map((id,i)=>({id,x:h[i].x+(Math.random()-.5)*40,y:h[i].y+50,tx:h[i].x,ty:h[i].y+50,lp:Math.random()*6.28}))}
initC();
function ts(x,y){return{x:innerWidth/2+(x+offsetX)*scale,y:innerHeight/2+(y+offsetY)*scale}}
function dH(p){const pos=HP[p.id];if(!pos)return;const s=ts(pos.x,pos.y),w=70*scale,h=50*scale,rH=30*scale;ctx.fillStyle='rgba(0,0,0,.2)';ctx.fillRect(s.x-w/2+3,s.y-h/2+3,w,h);ctx.fillStyle=p.wallColor;ctx.fillRect(s.x-w/2,s.y-h/2,w,h);ctx.strokeStyle='rgba(255,255,255,.2)';ctx.lineWidth=1;ctx.strokeRect(s.x-w/2,s.y-h/2,w,h);ctx.beginPath();ctx.moveTo(s.x-w/2-5*scale,s.y-h/2);ctx.lineTo(s.x,s.y-h/2-rH);ctx.lineTo(s.x+w/2+5*scale,s.y-h/2);ctx.closePath();ctx.fillStyle=p.roofColor;ctx.fill();ctx.fillStyle='rgba(0,0,0,.4)';ctx.fillRect(s.x-5*scale,s.y+h/2-18*scale,10*scale,18*scale);const wc=isN()?'rgba(255,230,100,.8)':'rgba(150,190,230,.5)';ctx.fillStyle=wc;[[-18,-8],[18,-8]].forEach(([ox,oy])=>{ctx.fillRect(s.x+ox*scale-6*scale,s.y+oy*scale-5*scale,12*scale,10*scale)});ctx.font=16*scale+'px serif';ctx.textAlign='center';ctx.fillText(p.emoji,s.x,s.y-h/2-rH-5*scale);ctx.font='bold '+10*scale+'px -apple-system,Arial Hebrew,sans-serif';ctx.fillStyle='#fff';ctx.fillText(p.name,s.x,s.y+h/2+14*scale)}
function dC(c){const s=ts(c.x,c.y),sz=14*scale,a=data.agents.find(a=>a.id===c.id);c.x+=(c.tx-c.x)*.02;c.y+=(c.ty-c.y)*.02;c.lp+=.15;ctx.beginPath();ctx.ellipse(s.x,s.y,sz,sz*.7,0,0,Math.PI*2);ctx.fillStyle='#E06030';ctx.fill();ctx.strokeStyle='#A03010';ctx.lineWidth=1.5;ctx.stroke();for(let d=-1;d<=1;d+=2)for(let i=0;i<3;i++){const la=Math.sin(c.lp+i*1.2)*.2,lx=s.x+d*sz*.9,ly=s.y+(i-1)*sz*.45;ctx.beginPath();ctx.moveTo(s.x+d*sz*.5,ly);ctx.lineTo(lx+Math.cos(la)*4*scale*d,ly+Math.sin(la)*3*scale);ctx.strokeStyle='#C04820';ctx.lineWidth=2.5*scale;ctx.stroke()}for(let d=-1;d<=1;d+=2){ctx.beginPath();ctx.moveTo(s.x+d*sz*.4,s.y-sz*.3);ctx.lineTo(s.x+d*sz*.8,s.y-sz*.5-4*scale);ctx.lineTo(s.x+d*sz*.8+d*3*scale,s.y-sz*.5+2*scale);ctx.strokeStyle='#E06030';ctx.lineWidth=3*scale;ctx.lineCap='round';ctx.stroke()}for(let d=-1;d<=1;d+=2){const ex=s.x+d*sz*.3,ey=s.y-sz*.6;ctx.beginPath();ctx.moveTo(ex,s.y-sz*.3);ctx.lineTo(ex,ey);ctx.strokeStyle='#C04820';ctx.lineWidth=2.5*scale;ctx.stroke();ctx.beginPath();ctx.arc(ex,ey,4*scale,0,6.28);ctx.fillStyle='#fff';ctx.fill();ctx.beginPath();ctx.arc(ex,ey,2*scale,0,6.28);ctx.fillStyle='#333';ctx.fill()}const bc=AC[c.id]||'#888';ctx.beginPath();ctx.arc(s.x,s.y,5*scale,0,6.28);ctx.fillStyle=bc;ctx.fill();ctx.strokeStyle='#fff';ctx.lineWidth=1.5;ctx.stroke();if(a){ctx.font='bold '+8*scale+'px -apple-system,Arial Hebrew,sans-serif';ctx.fillStyle=bc;ctx.textAlign='center';ctx.fillText(a.name,s.x,s.y+sz+10*scale)}}
function dF(){const s=ts(0,0),r=18*scale;ctx.beginPath();ctx.arc(s.x,s.y,r,0,6.28);ctx.fillStyle='rgba(60,130,190,.5)';ctx.fill();ctx.strokeStyle='rgba(100,140,160,.8)';ctx.lineWidth=2;ctx.stroke();for(let i=0;i<3;i++){const a=af*.03+i*2.1,dx=Math.cos(a)*6*scale,dy=-Math.abs(Math.sin(af*.06+i))*10*scale;ctx.beginPath();ctx.arc(s.x+dx,s.y+dy,2*scale,0,6.28);ctx.fillStyle='rgba(120,180,255,.7)';ctx.fill()}}
function dP(){const c=[['matzpen','alon-dev'],['dekel','aliza'],['boker','games'],['matzpen','dekel'],['alon-dev','aliza'],['matzpen','boker'],['alon-dev','boker'],['dekel','games'],['aliza','games']];ctx.strokeStyle='rgba(139,115,85,.4)';ctx.lineWidth=6*scale;ctx.lineCap='round';c.forEach(([a,b])=>{const pa=HP[a],pb=HP[b];if(!pa||!pb)return;const sa=ts(pa.x,pa.y),sb=ts(pb.x,pb.y);ctx.beginPath();ctx.moveTo(sa.x,sa.y);ctx.quadraticCurveTo((sa.x+sb.x)/2,(sa.y+sb.y)/2+10*scale,sb.x,sb.y);ctx.stroke()})}
function dT(){[[-300,-180],[300,-180],[-300,180],[300,180],[0,-310],[0,310],[-350,0],[350,0]].forEach(([tx,ty])=>{const s=ts(tx,ty),r=14*scale;ctx.fillStyle='#5C3A1E';ctx.fillRect(s.x-2*scale,s.y,4*scale,10*scale);ctx.beginPath();ctx.arc(s.x,s.y-2*scale,r,0,6.28);ctx.fillStyle='#2A6B2A';ctx.fill()})}
function isN(){const h=new Date().getHours();return h>=19||h<6}
function draw(){af++;const w=innerWidth,h=innerHeight;ctx.clearRect(0,0,w,h);ctx.fillStyle=isN()?'#0d2a0d':'#1a5c2a';ctx.fillRect(0,0,w,h);if(isN()){ctx.fillStyle='rgba(0,0,40,.25)';ctx.fillRect(0,0,w,h)}dP();dT();dF();data.projects.forEach(dH);crabs.forEach(dC);if(af%180===0)crabs.forEach(c=>{const h=Object.values(HP),t=h[Math.floor(Math.random()*h.length)];c.tx=t.x+(Math.random()-.5)*40;c.ty=t.y+50+(Math.random()-.5)*20});requestAnimationFrame(draw)}
canvas.addEventListener('click',e=>{const cx=innerWidth/2,cy=innerHeight/2,wx=(e.clientX-cx)/scale-offsetX,wy=(e.clientY-cy)/scale-offsetY;for(const p of data.projects){const pos=HP[p.id];if(!pos)continue;if(Math.abs(wx-pos.x)<45&&Math.abs(wy-pos.y)<40){showP(p);return}}closePanel()});
let ltd=0,lt=null;
canvas.addEventListener('touchstart',e=>{if(e.touches.length===2){const dx=e.touches[0].clientX-e.touches[1].clientX,dy=e.touches[0].clientY-e.touches[1].clientY;ltd=Math.hypot(dx,dy)}if(e.touches.length===1)lt={x:e.touches[0].clientX,y:e.touches[0].clientY}});
canvas.addEventListener('touchmove',e=>{e.preventDefault();if(e.touches.length===2){const dx=e.touches[0].clientX-e.touches[1].clientX,dy=e.touches[0].clientY-e.touches[1].clientY,d=Math.hypot(dx,dy);scale*=d/ltd;scale=Math.max(.3,Math.min(3,scale));ltd=d}else if(e.touches.length===1&&lt){offsetX+=(e.touches[0].clientX-lt.x)/scale;offsetY+=(e.touches[0].clientY-lt.y)/scale;lt={x:e.touches[0].clientX,y:e.touches[0].clientY}}},{passive:false});
canvas.addEventListener('touchend',()=>{lt=null});
function showP(p){const panel=document.getElementById('info-panel'),c=document.getElementById('panel-content');c.innerHTML='<h2>'+p.emoji+' '+p.name+'</h2><div class="row"><span class="label">קבצים</span><span>'+p.fileCount+'</span></div><div class="row"><span class="label">משימות</span><span>'+p.activeTasks+'</span></div>';panel.classList.add('open')}
function closePanel(){document.getElementById('info-panel').classList.remove('open')}
async function fetchS(){try{const r=await fetch('/api/status');data=await r.json();document.getElementById('task-count').textContent='⚡ '+data.tasks.length;const h=new Date().getHours(),ps=[[6,'🌅'],[8,'☀️'],[17,'🌇'],[19,'🌆'],[22,'🌙']];let p='🌙';for(const[hr,t]of ps)if(h>=hr)p=t;document.getElementById('time-badge').textContent=p}catch(e){}}
fetchS();setInterval(fetchS,15000);draw();
</script>
</body>
</html>
"""
    }
}
