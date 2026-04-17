/// 字体大小选项枚举
enum FontSizeOption { small, medium, large }

/// 字体大小映射表
const Map<FontSizeOption, double> fontSizeMap = {
  FontSizeOption.small: 13.0,
  FontSizeOption.medium: 15.0,
  FontSizeOption.large: 18.0,
};

/// 字体大小标签映射表（中文）
const Map<FontSizeOption, String> fontSizeLabels = {
  FontSizeOption.small: '小',
  FontSizeOption.medium: '中',
  FontSizeOption.large: '大',
};

/// 行高选项
const List<double> lineHeightOptions = [1.5, 1.75, 2.0];

/// 字间距选项
const List<double> letterSpacingOptions = [0.0, 0.5, 1.0, 2.0];
