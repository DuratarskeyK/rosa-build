function changeCheck(el)
/* 
	������� ����� ���� � �������� ��������
	el - span ��������� ��� �������� ��������
	input - �������
*/
{
     var el = el,
          input = el.getElementsByTagName("input")[0];
		
     if(input.checked)
     {
	     el.style.backgroundPosition="0 0"; 
		 input.checked=false;
     }
     else
     {
          el.style.backgroundPosition="0 -17px"; 
		  input.checked=true;
     }
     return true;
}
function startChangeCheck(el)
/*
	���� �������� ����������� � on, ������ ��� �������� �� ����������
*/
{
	var el = el,
          input = el.getElementsByTagName("input")[0];
     if(input.checked)
     {
          el.style.backgroundPosition="0 -17px";     
      }
     return true;
}

function startCheck()
{
	/*
		 ��� �������� �������� �������� ��������� �������� �������� � ��������� ���������.
		 ���� ��������� ���������, ����� ����� ��������� ��� ������� �������� � ������� id
	 */
	startChangeCheck(document.getElementById("niceCheckbox1"));
}