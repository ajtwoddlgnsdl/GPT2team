class AlbumItem {
  final String id;
  final String title;
  final String description;
  final String imagePath;
  final String hint;
  final int unlockDay;
  final String unlockZone;

  const AlbumItem({
    required this.id,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.hint,
    required this.unlockDay,
    required this.unlockZone,
  });
}

const Map<String, List<AlbumItem>> kHeroineAlbumMetadata = {
  "리안": [
    AlbumItem(
      id: "lian_riding_day3",
      title: "소나기 속 웃음",
      description: "갑작스러운 비를 피해 들어간 처마 아래, 처음 마주한 리안의 환한 웃음.",
      imagePath: "assets/images/bg/rian_day3.jpg",
      hint: "Day 3 밤 스토리 감상 후 해금",
      unlockDay: 3,
      unlockZone: "밤",
    ),
    AlbumItem(
      id: "lian_morning_day9",
      title: "낯선 아침",
      description: "평소와 다른 모습으로 마주한 리안의 아침.",
      imagePath: "assets/images/bg/rian_day9.png",
      hint: "Day 9 아침 스토리 감상 후 해금",
      unlockDay: 9,
      unlockZone: "아침",
    ),
    AlbumItem(
      id: "lian_cafe_day14",
      title: "소리를 담는 밤",
      description: "늦은 카페에서 리안과 함께 모은 소리.",
      imagePath: "assets/images/bg/rian_day14_event.png",
      hint: "Day 14 저녁 스토리 감상 후 해금",
      unlockDay: 14,
      unlockZone: "저녁",
    ),
    AlbumItem(
      id: "lian_ending_bad",
      title: "엇갈린 소리",
      description: "끝내 서로에게 닿지 못한 두 사람의 결말.",
      imagePath: "assets/images/bg/ENDING_BAD_rian.png",
      hint: "리안 배드 엔딩 감상 후 해금",
      unlockDay: 20,
      unlockZone: "엔딩",
    ),
    AlbumItem(
      id: "lian_ending_normal",
      title: "남겨진 여운",
      description: "각자의 자리에서 이어지는 리안과의 인연.",
      imagePath: "assets/images/bg/ENDING_NORMAL_rian.png",
      hint: "리안 노멀 엔딩 감상 후 해금",
      unlockDay: 20,
      unlockZone: "엔딩",
    ),
    AlbumItem(
      id: "lian_ending_true",
      title: "함께 만드는 음악",
      description: "두 사람의 소리가 하나의 곡으로 이어진 순간.",
      imagePath: "assets/images/bg/ENDING_TRUE_rian.png",
      hint: "리안 트루 엔딩 감상 후 해금",
      unlockDay: 20,
      unlockZone: "엔딩",
    ),
  ],
  "이서연": [
    AlbumItem(
      id: "seoyeon_flowershop",
      title: "꽃집의 만남",
      description: "향기로운 꽃들 사이로 번지는 미소.",
      imagePath: "assets/images/bg/flowershop.png",
      hint: "Day 9 아침 스토리 감상 후 해금",
      unlockDay: 9,
      unlockZone: "아침",
    ),
  ],
  "코토리": [
    AlbumItem(
      id: "kotori_cafe",
      title: "카페 알바",
      description: "서툴지만 최선을 다하는 귀여운 모습.",
      imagePath: "assets/images/bg/cafe.jpg",
      hint: "Day 9 낮 스토리 감상 후 해금",
      unlockDay: 9,
      unlockZone: "낮",
    ),
  ]
};
