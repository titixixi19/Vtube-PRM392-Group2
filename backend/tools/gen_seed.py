# Sinh file seed.sql (dữ liệu mẫu). Chạy: python tools/gen_seed.py
import os
OUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'main', 'resources', 'seed.sql')
PW = '$2a$10$ueBcRZp.K9su92eGHMstt.OLePw6NDKwm3hPmKAY8.BP1wROq9dni'  # = 123456
S = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/'
LONG = [('BigBuckBunny', 596), ('ElephantsDream', 653), ('Sintel', 888), ('TearsOfSteel', 734),
        ('SubaruOutbackOnStreetAndDirt', 594), ('VolkswagenGTIReview', 594), ('WeAreGoingOnBullrun', 594),
        ('WhatCarCanYouGetForAGrand', 609), ('ForBiggerFun', 60)]
SHORT = [('ForBiggerBlazes', 15), ('ForBiggerEscapes', 15), ('ForBiggerJoyrides', 15), ('ForBiggerMeltdowns', 15)]

def q(s):
    return 'NULL' if s is None else "'" + str(s).replace("'", "''") + "'"
def ago(expr):
    return f"strftime('%Y-%m-%dT%H:%M:%SZ','now','{expr}')"

out = ['-- Dữ liệu mẫu, sinh bởi tools/gen_seed.py. INSERT OR IGNORE nên chạy lại không bị trùng.',
       '-- Mọi tài khoản mẫu có mật khẩu: 123456']

users = [  # id, email, name, handle, verified, subs, avatar img, description
    (1, 'demo@vtube.vn', 'Nguyễn Văn A', 'nguyenvana', 0, 12, 12, 'Kênh cá nhân của Nguyễn Văn A.'),
    (2, 'vtech@vtube.vn', 'VTech Studio', 'vtechstudio', 1, 1500000, 59, 'Kênh chia sẻ kiến thức lập trình Fullstack, Mobile App Flutter, DevOps và kiến trúc hệ thống.'),
    (3, 'amthucbui@vtube.vn', 'Ẩm Thực Bụi', 'amthucbui', 1, 320000, 33, 'Khám phá ẩm thực đường phố Việt Nam.'),
    (4, 'vietnamvibes@vtube.vn', 'Vietnam Vibes', 'vietnam_vibes', 1, 210000, 47, 'Du lịch và những góc phố đẹp của Việt Nam.'),
    (5, 'laptrinhdd@vtube.vn', 'Lập Trình Di Động', 'laptrinhdidong', 1, 128000, 68, 'Học Flutter, Android, iOS từ con số 0.'),
    (6, 'chillmelody@vtube.vn', 'Chill Melody', 'chillmelody', 0, 450000, 25, 'Nhạc lofi, chill để học và làm việc.'),
    (7, 'goccongnghe@vtube.vn', 'Góc Công Nghệ', 'goccongnghe', 0, 98000, 15, 'Review thiết bị, setup góc làm việc.'),
]
for (i, email, name, handle, ver, subs, img, desc) in users:
    av = f'https://i.pravatar.cc/300?img={img}'
    out.append(f"INSERT OR IGNORE INTO users (id,email,password_hash,display_name,avatar_url,created_at) VALUES ({i},{q(email)},{q(PW)},{q(name)},{q(av)},{ago('-400 days')});")
    out.append(f"INSERT OR IGNORE INTO channels (id,user_id,name,handle,description,avatar_url,banner_url,verified,subscriber_count,created_at) VALUES ({i},{i},{q(name)},{q(handle)},{q(desc)},{q(av)},{q(f'https://picsum.photos/seed/banner{i}/1280/320')},{ver},{subs},{ago('-400 days')});")
    # mỗi user có sẵn 2 playlist hệ thống: id = 2*i-1 (liked), 2*i (watch_later)
    out.append(f"INSERT OR IGNORE INTO playlists (id,user_id,title,visibility,kind) VALUES ({2*i-1},{i},'Video đã thích','private','liked');")
    out.append(f"INSERT OR IGNORE INTO playlists (id,user_id,title,visibility,kind) VALUES ({2*i},{i},'Xem sau','private','watch_later');")

cats = [(1, 'Âm nhạc', 'music'), (2, 'Trò chơi', 'gaming'), (3, 'Tin tức', 'news'), (4, 'Giáo dục', 'education'),
        (5, 'Ẩm thực', 'food'), (6, 'Du lịch', 'travel'), (7, 'Công nghệ', 'tech'), (8, 'Giải trí', 'entertainment'),
        (9, 'Thể thao', 'sports')]
for c in cats:
    out.append(f"INSERT OR IGNORE INTO categories (id,name,slug) VALUES ({c[0]},{q(c[1])},{q(c[2])});")

videos = [  # channel, title, category, views, likes, age
    (2, 'Xây dựng ứng dụng Streaming tốc độ cao với Flutter & WebSockets từ A - Z', 7, 245000, 14000, '-14 days'),
    (2, 'Học Docker & Kubernetes từ cơ bản đến nâng cao', 7, 128000, 6200, '-15 days'),
    (2, 'Tối ưu hóa Database PostgreSQL xử lý 100.000 request/giây', 7, 89000, 4100, '-30 days'),
    (2, 'Microservices với Golang & gRPC: Xây dựng hệ thống thực tế', 7, 64000, 3300, '-35 days'),
    (2, 'Lập trình AI Agent với Next.js và Gemini API', 4, 15000, 1200, '-2 hours'),
    (3, 'Khám phá 10 quán ăn đêm Sài Gòn', 5, 89000, 5400, '-7 days'),
    (3, 'Cách nấu Phở Bò gia truyền chuẩn vị Hà Nội', 5, 850000, 42000, '-7 days'),
    (3, 'Ẩm thực phố cổ Hà Nội về đêm', 5, 310000, 18000, '-8 days'),
    (4, 'Hà Nội mùa thu qua lăng kính cinematic', 6, 48000, 3900, '-8 hours'),
    (4, 'Hành trình phượt Tây Bắc mùa lúa chín', 6, 520000, 31000, '-60 days'),
    (4, 'Một ngày ở Đà Lạt chỉ với 500 nghìn', 6, 230000, 12000, '-20 days'),
    (5, 'Hướng dẫn xây dựng ứng dụng với Flutter & Firebase cho người mới', 4, 1200000, 56000, '-3 days'),
    (5, 'Tự học Flutter từ con số 0: Xây dựng ứng dụng đầu tiên', 4, 120000, 8000, '-90 days'),
    (5, 'Flutter Bloc vs Provider: Chọn state management nào?', 4, 45000, 2900, '-14 days'),
    (5, 'Có gì mới trong Flutter? Trải nghiệm thực tế', 4, 18000, 1100, '-5 days'),
    (6, 'Lofi Hip Hop Chill Beats - Nhạc học bài thư giãn', 1, 310000, 22000, '-5 days'),
    (6, 'Nhạc không lời tập trung làm việc 2 giờ', 1, 640000, 35000, '-45 days'),
    (6, 'Piano mưa đêm - Ngủ ngon', 1, 1900000, 88000, '-120 days'),
    (7, 'Setup bàn làm việc tối giản phong cách Cyberpunk', 7, 98000, 6000, '-5 days'),
    (7, 'Review bàn phím cơ không dây dưới 1 triệu', 7, 76000, 4300, '-12 days'),
    (7, 'Top 5 tai nghe chống ồn đáng mua', 7, 54000, 2100, '-25 days'),
    (2, 'Trận đấu Esports chung kết - Highlights', 2, 410000, 19000, '-3 days'),
    (4, 'Tin nhanh du lịch: Những điểm đến hot cuối năm', 3, 33000, 900, '-1 days'),
    (7, 'Bóng đá phủi cuối tuần cùng team Góc Công Nghệ', 9, 21000, 1500, '-6 days'),
]
vid = 0
for n, (ch, title, cat, views, likes, age) in enumerate(videos):
    vid += 1
    name, dur = LONG[n % len(LONG)]
    out.append(f"INSERT OR IGNORE INTO videos (id,channel_id,title,description,thumbnail_url,video_url,duration_seconds,view_count,like_count,dislike_count,category_id,is_short,tags,published_at) VALUES ({vid},{ch},{q(title)},{q('Video mẫu của VTube: ' + title + '. #vtube #demo')},{q(f'https://picsum.photos/seed/vtube{vid}/640/360')},{q(S + name + '.mp4')},{dur},{views},{likes},{likes//40},{cat},0,'vtube,demo',{ago(age)});")
# 1 video đang phát trực tiếp
vid += 1
out.append(f"INSERT OR IGNORE INTO videos (id,channel_id,title,description,thumbnail_url,video_url,duration_seconds,view_count,like_count,category_id,is_short,is_live,published_at) VALUES ({vid},3,'TRỰC TIẾP: Trải nghiệm ẩm thực đêm Chợ Lớn Sài Gòn','Livestream mẫu',{q(f'https://picsum.photos/seed/vtube{vid}/640/360')},{q(S + 'BigBuckBunny.mp4')},0,3200,400,5,0,1,{ago('-30 minutes')});")
LIVE_ID = vid

shorts = [(4, 'Góc quán cà phê trứng view triệu đô giữa phố cổ #hanoi', 6, 320000, 48200),
          (5, 'Top 5 packages Flutter cực đỉnh 🔥', 4, 480000, 21000),
          (5, 'Tối ưu hiệu năng Flutter mượt 120Hz', 4, 195000, 9000),
          (7, 'Visual Effect chỉ 1 click trong CapCut', 8, 1400000, 70000),
          (3, 'Mẹo pha cà phê muối béo ngậy tại nhà ☕', 5, 320000, 15000),
          (6, '30 giây lofi cho buổi sáng', 1, 88000, 5000),
          (2, 'Mẹo Git ai cũng nên biết #shorts', 7, 260000, 13000),
          (7, 'Pha lật kèo rank Thách Đấu', 2, 890000, 41000)]
for n, (ch, title, cat, views, likes) in enumerate(shorts):
    vid += 1
    name, dur = SHORT[n % len(SHORT)]
    out.append(f"INSERT OR IGNORE INTO videos (id,channel_id,title,description,thumbnail_url,video_url,duration_seconds,view_count,like_count,category_id,is_short,published_at) VALUES ({vid},{ch},{q(title)},{q(title)},{q(f'https://picsum.photos/seed/short{vid}/360/640')},{q(S + name + '.mp4')},{dur},{views},{likes},{cat},1,{ago(f'-{n+1} days')});")

# Bình luận cho video 1 (của VTech Studio)
comments = [  # id, video, user, parent, content, likes, pinned, hearted, age
    (1, 1, 2, None, 'Mã nguồn GitHub và tài liệu API miễn phí các bạn xem ở phần mô tả nhé! Chúc mọi người code vui vẻ ❤️', 3400, 1, 0, '-14 days'),
    (2, 1, 5, None, 'Video hay quá anh ơi, phần giải thích về WebSockets giải quyết được đúng lỗi em đang gặp tuần này!', 124, 0, 1, '-2 days'),
    (3, 1, 7, 2, 'Chuẩn luôn bác, trước em dùng polling giật tung chảo', 8, 0, 0, '-1 days'),
    (4, 1, 5, 2, 'Công nhận, chuyển qua WS mượt hẳn!', 3, 0, 0, '-20 hours'),
    (5, 1, 4, None, 'Giao diện app mẫu trong video thiết kế nhìn clean và chuẩn Material Design quá ạ 🥰', 58, 0, 0, '-3 days'),
    (6, 1, 3, None, 'Anh làm thêm video về CI/CD triển khai Docker lên VPS nữa thì trọn bộ luôn ạ!', 32, 0, 0, '-4 days'),
    (7, 7, 1, None, 'Nhìn ngon quá, cuối tuần phải làm thử mới được.', 12, 0, 0, '-5 days'),
    (8, 7, 4, None, 'Nước dùng trong veo, chuẩn vị Hà Nội luôn.', 40, 0, 0, '-6 days'),
]
for (cid, v, u, p, content, likes, pin, heart, age) in comments:
    out.append(f"INSERT OR IGNORE INTO comments (id,video_id,user_id,parent_id,content,like_count,is_pinned,is_hearted,created_at) VALUES ({cid},{v},{u},{'NULL' if p is None else p},{q(content)},{likes},{pin},{heart},{ago(age)});")
out.append("UPDATE comments SET reply_count = (SELECT COUNT(*) FROM comments r WHERE r.parent_id = comments.id);")
out.append("UPDATE videos SET comment_count = (SELECT COUNT(*) FROM comments c WHERE c.video_id = videos.id);")

# Dữ liệu cá nhân của tài khoản demo (user 1)
for ch in (2, 3, 4, 5, 6):
    out.append(f"INSERT OR IGNORE INTO subscriptions (user_id,channel_id,notify_mode,created_at) VALUES (1,{ch},'all',{ago('-100 days')});")
for v in (1, 7, 12, 16):
    out.append(f"INSERT OR IGNORE INTO video_reactions (user_id,video_id,value) VALUES (1,{v},1);")
for pos, v in enumerate((1, 7, 12, 16)):
    out.append(f"INSERT OR IGNORE INTO playlist_videos (playlist_id,video_id,position) VALUES (1,{v},{pos});")
for pos, v in enumerate((3, 10)):
    out.append(f"INSERT OR IGNORE INTO playlist_videos (playlist_id,video_id,position) VALUES (2,{v},{pos});")
out.append(f"INSERT OR IGNORE INTO playlists (id,user_id,title,description,visibility,kind) VALUES (100,1,'Học Flutter','Các video Flutter hay','public','custom');")
for pos, v in enumerate((12, 13, 14, 15)):
    out.append(f"INSERT OR IGNORE INTO playlist_videos (playlist_id,video_id,position) VALUES (100,{v},{pos});")
hist = [(1, 300, '-1 hours'), (6, 200, '-3 hours'), (2, 1000, '-1 days'), (16, 1500, '-1 days'), (3, 100, '-5 days'), (26, 10, '-2 hours')]
for v, prog, age in hist:
    out.append(f"INSERT OR IGNORE INTO watch_history (user_id,video_id,progress_seconds,watched_at) VALUES (1,{v},{prog},{ago(age)});")
for kw, age in (('flutter tutorial cho người mới bắt đầu', '-1 days'), ('nhạc lofi chill học bài', '-2 days'),
                ('vtech studio websocket', '-3 days'), ('review bàn phím cơ không dây', '-4 days')):
    out.append(f"INSERT OR IGNORE INTO search_history (user_id,keyword,searched_at) VALUES (1,{q(kw)},{ago(age)});")
notis = [(1, 'new_video', 2, 5, None, 'VTech Studio đã tải lên: Lập trình AI Agent với Next.js và Gemini API', 0, '-2 hours'),
         (2, 'comment_reply', 5, 7, 7, '@laptrinhdidong đã trả lời bình luận của bạn: "Công nhận ngon thật"', 0, '-4 hours'),
         (3, 'live', 3, LIVE_ID, None, 'Ẩm Thực Bụi đang phát trực tiếp: Trải nghiệm ẩm thực đêm Chợ Lớn Sài Gòn', 1, '-1 days'),
         (4, 'new_short', 4, 26, None, 'Vietnam Vibes đã đăng một Short mới', 1, '-2 days'),
         (5, 'new_subscriber', 7, None, None, '@goccongnghe đã đăng ký kênh của bạn', 1, '-3 days')]
for (nid, t, actor, v, c, msg, read, age) in notis:
    out.append(f"INSERT OR IGNORE INTO notifications (id,user_id,type,actor_channel_id,video_id,comment_id,message,is_read,created_at) VALUES ({nid},1,{q(t)},{actor},{'NULL' if v is None else v},{'NULL' if c is None else c},{q(msg)},{read},{ago(age)});")

open(OUT, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('wrote', OUT, len(out), 'lines; live id', LIVE_ID, 'last video id', vid)
