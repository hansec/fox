module m_dom_utils

  use m_common_array_str, only: str_vs, vs_str_alloc, vs_vs_alloc
  use m_common_format, only: operator(//)
  use m_dom_types, only: Node, Namednodemap, Node
  use m_dom_types, only: DOCUMENT_NODE, ELEMENT_NODE, TEXT_NODE, CDATA_SECTION_NODE
  use m_dom_types, only: COMMENT_NODE

  use m_dom_node, only: haschildnodes
  use m_dom_namednodemap, only: getlength, item

  use m_common_attrs, only: dictionary_t, add_item_to_dict, getValue, hasKey, init_dict, destroy_dict

  use FoX_wxml, only: xmlf_t
  use FoX_wxml, only: xml_OpenFile, xml_Close
  use FoX_wxml, only: xml_AddXMLDeclaration
  use FoX_wxml, only: xml_DeclareNamespace
  use FoX_wxml, only: xml_AddAttribute
  use FoX_wxml, only: xml_AddCharacters
  use FoX_wxml, only: xml_NewElement
  use FoX_wxml, only: xml_EndElement
  use FoX_wxml, only: xml_AddComment

  implicit none

  public :: dumpTree
  public :: serialize

  private

contains

  subroutine dumpTree(startNode)

    type(Node), pointer :: startNode   

    integer           :: indent_level

    indent_level = 0

    call dump2(startNode)

  contains

    recursive subroutine dump2(input)
      type(Node), pointer :: input
      type(Node), pointer :: temp     
      temp => input
      do while(associated(temp))
         write(*,'(3a,i0)') repeat(' ', indent_level), &
                        str_vs(temp%nodeName), " of type ", &
                        temp%nodeType
         if (hasChildNodes(temp)) then
            indent_level = indent_level + 3
            call dump2(temp%firstChild)
            indent_level = indent_level - 3
         endif
         temp => temp%nextSibling
      enddo

    end subroutine dump2

  end subroutine dumpTree
!----------------------------------------------------------------

  subroutine serialize(startNode,Name)

    type(Node), pointer :: startNode   
    character(len=*), intent(in) :: Name

    type(xmlf_t)  :: xf

    call xml_OpenFile(Name,xf)
    if (startNode%nodeType==DOCUMENT_NODE) then
      ! make sure and dump all document meta-stuff first
      continue
    endif
    call dump_xml(xf, startNode)
    call xml_Close(xf)

  end subroutine serialize

  recursive subroutine dump_xml(xf, input)
    type(xmlf_t)  :: xf
    type(Node), pointer         :: input
    type(Node), pointer         :: n, attr, child
    type(NamedNodeMap), pointer :: attr_map
    integer  ::  i
    integer, save :: nns = -1
    type(dictionary_t), save :: simpleDict
    character, pointer :: prefix(:), elementQName(:)

    call init_dict(simpleDict)

    n => input
    if (.not. associated(n)) return
    select case (n%nodeType)

    case (DOCUMENT_NODE)
      call dump_xml(xf, n%documentElement)
      
    case (ELEMENT_NODE)
      
      if (size(n%namespaceURI)==0) then
        elementQName => vs_vs_alloc(n%nodeName)
      else
        if (hasKey(simpleDict, str_vs(n%namespaceURI))) then
          prefix = getValue(simpleDict, str_vs(n%namespaceURI))
        else
          nns = nns + 1
          if (nns == 0) then
            allocate(prefix(0))
          else
            prefix => vs_str_alloc('ns'//nns)
          endif
          call add_item_to_dict(simpleDict, str_vs(n%namespaceURI), str_vs(n%prefix))
        endif
        if (size(prefix)==0) then
          elementQName => vs_vs_alloc(n%nodeName)
        else
          elementQName => vs_str_alloc(str_vs(n%prefix)//":"//str_vs(n%nodeName))
        endif
      endif
      call xml_NewElement(xf, str_vs(elementQName))
      if (size(n%namespaceURI)==0) then
        if (size(prefix)==0) then
          call xml_DeclareNamespace(xf, str_vs(n%namespaceURI))
        else
          call xml_DeclareNamespace(xf, str_vs(n%namespaceURI), str_vs(n%prefix))
        endif
      endif
      deallocate(prefix)
      !TOHW need to check for & print out attribute namespaces as well.
      attr_map => n%attributes
      do i = 0, getLength(attr_map) - 1
        attr => item(attr_map,i)
        call xml_AddAttribute(xf, str_vs(attr%nodeName), str_vs(attr%nodeValue))
      enddo
      child => n%firstChild
      do while (associated(child))
        call dump_xml(xf, child)
        child => child%nextSibling
      enddo
      call xml_EndElement(xf,str_vs(elementQName))
      deallocate(elementQName)
      
    case (TEXT_NODE)
      
      call xml_AddCharacters(xf, str_vs(n%nodeValue))
      
    case (CDATA_SECTION_NODE)
      
      call xml_AddCharacters(xf, str_vs(n%nodeValue), parsed=.false.)
      
    case (COMMENT_NODE)
      
      call xml_AddComment(xf, str_vs(n%nodeValue))
      
    end select
    call destroy_dict(simpleDict)

  end subroutine dump_xml
  
end module m_dom_utils
