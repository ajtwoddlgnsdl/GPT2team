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
      id: "lian_first_meet",
      title: "첫 만남",
      description: "차가운 밤거리에서 만난 인연.",
      imagePath: "assets/images/bg/rian_cafe_street_night.png",
      hint: "Day 1 밤 스토리 감상 후 해금",
      unlockDay: 1,
      unlockZone: "밤",
    ),
    AlbumItem(
      id: "lian_home_lobby",
      title: "리안의 집",
      description: "처음으로 가본 그녀의 개인 공간.",
      imagePath: "assets/images/bg/rian_home_ground_floor.png",
      hint: "Day 2 밤 스토리 감상 후 해금",
      unlockDay: 2,
      unlockZone: "밤",
    ),
    AlbumItem(
      id: "lian_riding_day3",
      title: "바이크 질주",
      description: "리안의 바이크 뒷자리에서 느낀 바람.",
      imagePath: "assets/images/bg/rian_day3.jpg",
      hint: "Day 3 밤 스토리 감상 후 해금",
      unlockDay: 3,
      unlockZone: "밤",
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
