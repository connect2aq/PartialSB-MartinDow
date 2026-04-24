public with sharing class UrlJoiner {
    // Joins base and path with exactly one slash between them
    public static String join(String base, String path) {
        if (String.isBlank(base)) return path;
        if (String.isBlank(path)) return base;
        String b = base.endsWith('/') ? base.left(base.length() - 1) : base;
        String p = path.startsWith('/') ? path.substring(1) : path;
        return b + '/' + p;
    }
}