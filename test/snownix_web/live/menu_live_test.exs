defmodule SnownixWeb.MenuLiveTest do
  use SnownixWeb.ConnCase

  import Phoenix.LiveViewTest
  import Snownix.NavigationFixtures

  @create_attrs %{
    link: "some link",
    newtab: true,
    parent_id: "some parent_id",
    status: "some status",
    title: "some title"
  }
  @update_attrs %{
    link: "some updated link",
    newtab: false,
    parent_id: "some updated parent_id",
    status: "some updated status",
    title: "some updated title"
  }
  @invalid_attrs %{link: nil, newtab: false, parent_id: nil, status: nil, title: nil}

  defp create_menu(_) do
    menu = menu_fixture()
    %{menu: menu}
  end

  describe "Index" do
    setup [:create_menu]

    test "lists all menus", %{conn: conn, menu: menu} do
      {:ok, _index_live, html} = live(conn, Routes.menu_index_path(conn, :index))

      assert html =~ "Listing Menus"
      assert html =~ menu.link
    end

    test "saves new menu", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, Routes.menu_index_path(conn, :index))

      assert index_live |> element("a", "New Menu") |> render_click() =~
               "New Menu"

      assert_patch(index_live, Routes.menu_index_path(conn, :new))

      assert index_live
             |> form("#menu-form", menu: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#menu-form", menu: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.menu_index_path(conn, :index))

      assert html =~ "Menu created successfully"
      assert html =~ "some link"
    end

    test "updates menu in listing", %{conn: conn, menu: menu} do
      {:ok, index_live, _html} = live(conn, Routes.menu_index_path(conn, :index))

      assert index_live |> element("#menu-#{menu.id} a", "Edit") |> render_click() =~
               "Edit Menu"

      assert_patch(index_live, Routes.menu_index_path(conn, :edit, menu))

      assert index_live
             |> form("#menu-form", menu: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#menu-form", menu: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.menu_index_path(conn, :index))

      assert html =~ "Menu updated successfully"
      assert html =~ "some updated link"
    end

    test "deletes menu in listing", %{conn: conn, menu: menu} do
      {:ok, index_live, _html} = live(conn, Routes.menu_index_path(conn, :index))

      assert index_live |> element("#menu-#{menu.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#menu-#{menu.id}")
    end
  end

  describe "Show" do
    setup [:create_menu]

    test "displays menu", %{conn: conn, menu: menu} do
      {:ok, _show_live, html} = live(conn, Routes.menu_show_path(conn, :show, menu))

      assert html =~ "Show Menu"
      assert html =~ menu.link
    end

    test "updates menu within modal", %{conn: conn, menu: menu} do
      {:ok, show_live, _html} = live(conn, Routes.menu_show_path(conn, :show, menu))

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Menu"

      assert_patch(show_live, Routes.menu_show_path(conn, :edit, menu))

      assert show_live
             |> form("#menu-form", menu: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#menu-form", menu: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.menu_show_path(conn, :show, menu))

      assert html =~ "Menu updated successfully"
      assert html =~ "some updated link"
    end
  end
end
