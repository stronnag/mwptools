public enum FWAPPROACH {
	maxapproach = 17,
}

namespace FWApproach {
	public struct approach {
		double appalt;
		double landalt;
		int dirn1;
		bool ex1;
		int dirn2;
		bool ex2;
		bool aref;
		bool dref;
	}

	private static approach approaches[17];

	public static approach get(int j) {
		return approaches[j];
	}

	public static void set(int j, approach l) {
		approaches[j] = l;
	}

	public static void set_appalt(int j, double d) {
		approaches[j].appalt = d;
	}

	public static void set_landalt(int j, double d) {
		approaches[j].landalt = d;
	}

	public static void set_dirn1(int j, int a1) {
		approaches[j].dirn1 = a1;
	}

	public static void set_dirn2(int j, int a2) {
		approaches[j].dirn2 = a2;
	}

	public static void set_ex1(int j, bool e1) {
		approaches[j].ex1 = e1;
	}

	public static void set_ex2(int j, bool e2) {
		approaches[j].ex1 = e2;
	}

	public static void set_aref(int j, bool ar) {
		approaches[j].aref = ar;
	}

	public static void set_dref(int j, bool dr) {
		approaches[j].dref = dr;
	}

	public bool is_active(int j) {
		return !(approaches[j].dirn1 == 0 && approaches[j].dirn2 == 0);
	}
}
