package com.vtube.api.channel;

import com.vtube.api.auth.Auth;
import com.vtube.api.common.PageResult;
import com.vtube.api.common.Paging;
import com.vtube.api.video.VideoDto;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Channels", description = "Màn 11, 12 - Trang kênh, đăng ký kênh")
@RestController
@RequestMapping("/api")
public class ChannelController {
    private final ChannelService channels;

    public ChannelController(ChannelService channels) {
        this.channels = channels;
    }

    public record SubscribeRequest(String notifyMode) {
    }

    @GetMapping("/channels/{id}")
    public ChannelDto get(@PathVariable long id) {
        return channels.get(Auth.userId(), id);
    }

    @GetMapping("/channels/handle/{handle}")
    public ChannelDto byHandle(@PathVariable String handle) {
        return channels.getByHandle(Auth.userId(), handle);
    }

    /** sort: newest | popular | oldest */
    @GetMapping("/channels/{id}/videos")
    public PageResult<VideoDto> videos(@PathVariable long id,
                                       @RequestParam(defaultValue = "newest") String sort,
                                       @RequestParam(required = false) Integer page,
                                       @RequestParam(required = false) Integer size) {
        return channels.videos(Auth.userId(), id, false, sort, Paging.of(page, size));
    }

    @GetMapping("/channels/{id}/shorts")
    public PageResult<VideoDto> shorts(@PathVariable long id,
                                       @RequestParam(defaultValue = "newest") String sort,
                                       @RequestParam(required = false) Integer page,
                                       @RequestParam(required = false) Integer size) {
        return channels.videos(Auth.userId(), id, true, sort, Paging.of(page, size));
    }

    @PutMapping("/channels/me")
    public ChannelDto updateMine(@RequestBody ChannelService.UpdateChannelRequest req) {
        return channels.updateMine(Auth.requireUserId(), req);
    }

    /** Đăng ký kênh hoặc đổi chế độ chuông. Body: { "notifyMode": "all" | "personalized" | "none" } */
    @PutMapping("/channels/{id}/subscription")
    public ChannelService.SubscriptionResult subscribe(@PathVariable long id,
                                                       @RequestBody(required = false) SubscribeRequest req) {
        return channels.subscribe(Auth.requireUserId(), id, req == null ? null : req.notifyMode());
    }

    @DeleteMapping("/channels/{id}/subscription")
    public ChannelService.SubscriptionResult unsubscribe(@PathVariable long id) {
        return channels.unsubscribe(Auth.requireUserId(), id);
    }

    /** sort: recent | az | relevance */
    @GetMapping("/me/subscriptions")
    public List<SubscriptionChannelDto> mySubscriptions(@RequestParam(defaultValue = "recent") String sort) {
        return channels.mySubscriptions(Auth.requireUserId(), sort);
    }

    /** type: all | today | video | short | live | continue | unwatched */
    @GetMapping("/me/subscriptions/feed")
    public PageResult<VideoDto> feed(@RequestParam(required = false) Long channelId,
                                     @RequestParam(defaultValue = "all") String type,
                                     @RequestParam(required = false) Integer page,
                                     @RequestParam(required = false) Integer size) {
        return channels.subscriptionFeed(Auth.requireUserId(), channelId, type, Paging.of(page, size));
    }
}
