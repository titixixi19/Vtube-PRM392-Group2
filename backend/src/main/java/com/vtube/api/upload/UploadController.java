package com.vtube.api.upload;

import com.vtube.api.auth.Auth;
import com.vtube.api.common.ApiException;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Tag(name = "Uploads", description = "Màn 15 - Upload file video / ảnh")
@RestController
@RequestMapping("/api/uploads")
public class UploadController {
    private static final List<String> VIDEO_EXT = List.of("mp4", "mov", "webm", "mkv", "3gp");
    private static final List<String> IMAGE_EXT = List.of("jpg", "jpeg", "png", "webp", "gif");
    private final Path dir;

    public UploadController(@Value("${app.upload-dir}") String uploadDir) {
        this.dir = Path.of(uploadDir).toAbsolutePath().normalize();
    }

    /**
     * Gửi multipart/form-data với field "file" và "type" = video | image.
     * Trả về url dạng "/uploads/abc.mp4" (đường dẫn tương đối, app tự ghép với địa chỉ server).
     */
    public record UploadResult(String url, String fileName, long size, String type) {
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<UploadResult> upload(@RequestParam("file") MultipartFile file,
                                               @RequestParam(defaultValue = "image") String type) throws IOException {
        Auth.requireUserId();
        if (file.isEmpty()) {
            throw ApiException.badRequest("File rỗng");
        }
        String original = file.getOriginalFilename() == null ? "" : file.getOriginalFilename();
        int dot = original.lastIndexOf('.');
        String ext = dot < 0 ? "" : original.substring(dot + 1).toLowerCase(Locale.ROOT);
        List<String> allowed = "video".equals(type) ? VIDEO_EXT : IMAGE_EXT;
        if (!allowed.contains(ext)) {
            throw ApiException.badRequest("Định dạng ." + ext + " không được hỗ trợ. Cho phép: " + allowed);
        }
        Files.createDirectories(dir);
        String name = UUID.randomUUID().toString().replace("-", "") + "." + ext;
        try (InputStream in = file.getInputStream()) {
            Files.copy(in, dir.resolve(name), StandardCopyOption.REPLACE_EXISTING);
        }
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new UploadResult("/uploads/" + name, original, file.getSize(), type));
    }
}
