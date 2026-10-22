package com.vtube.api.user;

import com.vtube.api.channel.ChannelBrief;
import com.vtube.api.common.ApiException;
import com.vtube.api.common.Db;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class UserService {
    private final Db db;

    public UserService(Db db) {
        this.db = db;
    }

    public MeDto getMe(long uid) {
        List<MeDto> rows = db.jdbc().query("""
                        SELECT u.id, u.email, u.display_name, u.avatar_url, u.history_paused, u.created_at,
                               c.id AS ch_id, c.name AS ch_name, c.handle AS ch_handle, c.avatar_url AS ch_avatar,
                               c.verified AS ch_verified, c.subscriber_count AS ch_subs
                        FROM users u JOIN channels c ON c.user_id = u.id
                        WHERE u.id = :uid""",
                Db.params().addValue("uid", uid),
                (rs, i) -> new MeDto(rs.getLong("id"), rs.getString("email"), rs.getString("display_name"),
                        rs.getString("avatar_url"), Db.bool(rs, "history_paused"), rs.getString("created_at"),
                        new ChannelBrief(rs.getLong("ch_id"), rs.getString("ch_name"), rs.getString("ch_handle"),
                                rs.getString("ch_avatar"), Db.bool(rs, "ch_verified"), rs.getLong("ch_subs"))));
        if (rows.isEmpty()) {
            throw ApiException.notFound("tài khoản");
        }
        return rows.get(0);
    }

    /** Đổi tên hiển thị / avatar. Avatar được đồng bộ sang kênh. Truyền null = giữ nguyên. */
    @Transactional
    public MeDto updateMe(long uid, String displayName, String avatarUrl) {
        db.jdbc().update("""
                        UPDATE users SET display_name = COALESCE(:name, display_name),
                                         avatar_url = COALESCE(:avatar, avatar_url)
                        WHERE id = :uid""",
                Db.params().addValue("name", blankToNull(displayName)).addValue("avatar", blankToNull(avatarUrl))
                        .addValue("uid", uid));
        if (blankToNull(avatarUrl) != null) {
            db.jdbc().update("UPDATE channels SET avatar_url = :avatar WHERE user_id = :uid",
                    Db.params().addValue("avatar", avatarUrl).addValue("uid", uid));
        }
        return getMe(uid);
    }

    public MeDto setHistoryPaused(long uid, boolean paused) {
        db.jdbc().update("UPDATE users SET history_paused = :p WHERE id = :uid",
                Db.params().addValue("p", paused ? 1 : 0).addValue("uid", uid));
        return getMe(uid);
    }

    public boolean isHistoryPaused(long uid) {
        return db.count("SELECT history_paused FROM users WHERE id = :uid", Db.params().addValue("uid", uid)) != 0;
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
