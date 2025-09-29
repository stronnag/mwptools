//  g++ -o wcam.exe wcam.cpp -lole32 -loleaut32 -lstrmiids

#include <windows.h>
#include <dshow.h>
#include <cstring>
#include <string.h>
#include <locale.h>

HRESULT EnumerateDevices(REFGUID category, IEnumMoniker **ppEnum) {
    HRESULT hr;
    ICreateDevEnum *pDevEnum = NULL;
    hr = CoCreateInstance(CLSID_SystemDeviceEnum, NULL, CLSCTX_INPROC_SERVER,
                          IID_ICreateDevEnum, (void **)&pDevEnum);

    if (SUCCEEDED(hr)) {
        hr = pDevEnum->CreateClassEnumerator(category, ppEnum, 0);
        if (hr == S_FALSE) {
            hr = VFW_E_NOT_FOUND; // The category is empty. Treat as an error.
        }
        pDevEnum->Release();
    }
    return hr;
}

char *to_utf8( wchar_t* wchars) {
  int nl = wcslen(wchars);
  int len = WideCharToMultiByte(CP_UTF8, 0, wchars, nl, 0, 0, NULL, NULL);
  char *lname = (char*)malloc(len+1);
  WideCharToMultiByte(CP_UTF8, 0, wchars, nl, lname, len, NULL, NULL);
  lname[len] = '\0';
  return lname;
}

int DisplayDeviceInformation(IEnumMoniker *pEnum, char ***buf, int *nlen) {
  int ni = 0;
  int nalloc = 16;
  HRESULT hr = 0;
  char **cbuf =  (char**)calloc(sizeof(char*), nalloc);

  IMoniker *pMoniker = NULL;

  while (pEnum->Next(1, &pMoniker, NULL) == S_OK) {
    IPropertyBag *pPropBag;
    hr = pMoniker->BindToStorage(0, 0, IID_PPV_ARGS(&pPropBag));
    if (FAILED(hr)) {
      pMoniker->Release();
      continue;
    }

    VARIANT var;
    VariantInit(&var);

    // Get description or friendly name.
    hr = pPropBag->Read(L"Description", &var, 0);
    if (FAILED(hr)) {
      hr = pPropBag->Read(L"FriendlyName", &var, 0);
    }
    char *fname = NULL;
    char *dname = NULL;

    if (SUCCEEDED(hr)) {
      fname = to_utf8(var.bstrVal);
      VariantClear(&var);
      hr = pPropBag->Read(L"DevicePath", &var, 0);
      if (SUCCEEDED(hr)) {
	dname = to_utf8(var.bstrVal);
	VariantClear(&var);
	int len = strlen(fname)+strlen(dname)+2;
	char *ostr = (char*)malloc(len);
	char *p = ostr;
	p = strcpy(p, fname);
	p += strlen(fname);
	*p++ = '\t';
	strcpy(p, dname);
	if(ni == nalloc) {
	  nalloc += 16;
	  cbuf = (char**)realloc(cbuf, (nalloc*sizeof(char*)));
	}
	cbuf[ni] = ostr;
	ni++;
      }
      if(fname != NULL) {
	free(fname);
      }
      if(dname != NULL) {
	free(dname);
      }
    }
    pPropBag->Release();
    pMoniker->Release();
  }

  *buf = cbuf;
  *nlen = ni;
  return hr;
}

extern "C"  int get_cameras(char ***pcams, int *nlen);
int get_cameras(char ***pcams, int*nlen) {
    HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    *pcams = NULL;
    *nlen = 0;
    if (SUCCEEDED(hr)) {
        IEnumMoniker *pEnum;
	hr = EnumerateDevices(CLSID_VideoInputDeviceCategory, &pEnum);
        if (SUCCEEDED(hr)) {
	  hr = DisplayDeviceInformation(pEnum, pcams, nlen);
	  pEnum->Release();
        }
        CoUninitialize();
    }
    return hr;
}
